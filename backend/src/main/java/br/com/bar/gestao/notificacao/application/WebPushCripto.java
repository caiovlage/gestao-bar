package br.com.bar.gestao.notificacao.application;

import javax.crypto.Cipher;
import javax.crypto.KeyAgreement;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.ByteArrayOutputStream;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.AlgorithmParameters;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.interfaces.ECPrivateKey;
import java.security.interfaces.ECPublicKey;
import java.security.spec.ECGenParameterSpec;
import java.security.spec.ECParameterSpec;
import java.security.spec.ECPoint;
import java.security.spec.ECPrivateKeySpec;
import java.security.spec.ECPublicKeySpec;
import java.util.Arrays;
import java.util.Base64;

/**
 * Criptografia do Web Push só com a JDK:
 * <ul>
 *   <li>RFC 8291 + RFC 8188 (aes128gcm): cifra a mensagem para a chave do navegador;</li>
 *   <li>RFC 8292 (VAPID): JWT ES256 que identifica este servidor ao serviço de push.</li>
 * </ul>
 */
public final class WebPushCripto {

    private static final SecureRandom ALEATORIO = new SecureRandom();
    private static final ECParameterSpec P256 = parametrosP256();
    private static final int TAMANHO_REGISTRO = 4096;

    private WebPushCripto() {
    }

    // ---------------------------------------------------------------- chaves

    /** Par de chaves P-256: [pública não comprimida (65 bytes), privada (32 bytes)], em base64url. */
    public static String[] gerarChavesVapid() {
        try {
            KeyPairGenerator g = KeyPairGenerator.getInstance("EC");
            g.initialize(new ECGenParameterSpec("secp256r1"), ALEATORIO);
            KeyPair par = g.generateKeyPair();
            return new String[] {
                    b64(pontoNaoComprimido((ECPublicKey) par.getPublic())),
                    b64(semSinal(((ECPrivateKey) par.getPrivate()).getS(), 32))
            };
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    // ---------------------------------------------------------------- VAPID

    /** Cabeçalho Authorization VAPID para o endpoint (válido por 12 h). */
    public static String autorizacaoVapid(String endpoint, String contato, String chavePublicaB64,
                                          String chavePrivadaB64, long agoraSegundos) {
        try {
            java.net.URI uri = java.net.URI.create(endpoint);
            String audiencia = uri.getScheme() + "://" + uri.getHost() + (uri.getPort() > 0 ? ":" + uri.getPort() : "");
            String cabecalho = b64("{\"typ\":\"JWT\",\"alg\":\"ES256\"}".getBytes(StandardCharsets.UTF_8));
            String corpo = b64(("{\"aud\":\"" + audiencia + "\",\"exp\":" + (agoraSegundos + 12 * 3600)
                    + ",\"sub\":\"" + contato + "\"}").getBytes(StandardCharsets.UTF_8));
            Signature s = Signature.getInstance("SHA256withECDSAinP1363Format");
            s.initSign(chavePrivada(b64d(chavePrivadaB64)));
            s.update((cabecalho + "." + corpo).getBytes(StandardCharsets.US_ASCII));
            String jwt = cabecalho + "." + corpo + "." + b64(s.sign());
            return "vapid t=" + jwt + ", k=" + chavePublicaB64;
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    // ---------------------------------------------------------------- RFC 8291

    /** Cifra a mensagem para o navegador (corpo da requisição, Content-Encoding: aes128gcm). */
    public static byte[] cifrar(byte[] mensagem, String p256dhB64, String authB64) {
        try {
            KeyPairGenerator g = KeyPairGenerator.getInstance("EC");
            g.initialize(new ECGenParameterSpec("secp256r1"), ALEATORIO);
            KeyPair efemera = g.generateKeyPair();
            byte[] salt = new byte[16];
            ALEATORIO.nextBytes(salt);
            return cifrar(mensagem, b64d(p256dhB64), b64d(authB64), (ECPrivateKey) efemera.getPrivate(),
                    pontoNaoComprimido((ECPublicKey) efemera.getPublic()), salt);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    /** Versão determinística (chave efêmera e salt informados), usada no teste com o vetor da RFC 8291. */
    static byte[] cifrar(byte[] mensagem, byte[] uaPublica, byte[] authSecret, ECPrivateKey asPrivada,
                         byte[] asPublica, byte[] salt) throws GeneralSecurityException {
        KeyAgreement ka = KeyAgreement.getInstance("ECDH");
        ka.init(asPrivada);
        ka.doPhase(chavePublica(uaPublica), true);
        byte[] ecdh = ka.generateSecret();

        // IKM = HKDF(auth_secret, ecdh, "WebPush: info\0" || ua_public || as_public, 32)
        byte[] prkChave = hmac(authSecret, ecdh);
        byte[] info = concat("WebPush: info\0".getBytes(StandardCharsets.US_ASCII), uaPublica, asPublica, new byte[] {1});
        byte[] ikm = hmac(prkChave, info);

        byte[] prk = hmac(salt, ikm);
        byte[] cek = Arrays.copyOf(hmac(prk, concat("Content-Encoding: aes128gcm\0".getBytes(StandardCharsets.US_ASCII),
                new byte[] {1})), 16);
        byte[] nonce = Arrays.copyOf(hmac(prk, concat("Content-Encoding: nonce\0".getBytes(StandardCharsets.US_ASCII),
                new byte[] {1})), 12);

        Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(cek, "AES"), new GCMParameterSpec(128, nonce));
        byte[] cifrado = c.doFinal(concat(mensagem, new byte[] {2}));   // 0x02 = último registro

        ByteBuffer cab = ByteBuffer.allocate(16 + 4 + 1 + asPublica.length);
        cab.put(salt).putInt(TAMANHO_REGISTRO).put((byte) asPublica.length).put(asPublica);
        return concat(cab.array(), cifrado);
    }

    // ---------------------------------------------------------------- auxiliares

    static ECPrivateKey chavePrivada(byte[] d) throws GeneralSecurityException {
        return (ECPrivateKey) KeyFactory.getInstance("EC").generatePrivate(new ECPrivateKeySpec(new BigInteger(1, d), P256));
    }

    static ECPublicKey chavePublica(byte[] ponto) throws GeneralSecurityException {
        if (ponto.length != 65 || ponto[0] != 4) throw new GeneralSecurityException("Chave pública P-256 inválida");
        ECPoint p = new ECPoint(new BigInteger(1, Arrays.copyOfRange(ponto, 1, 33)),
                new BigInteger(1, Arrays.copyOfRange(ponto, 33, 65)));
        return (ECPublicKey) KeyFactory.getInstance("EC").generatePublic(new ECPublicKeySpec(p, P256));
    }

    static byte[] pontoNaoComprimido(ECPublicKey k) {
        return concat(new byte[] {4}, semSinal(k.getW().getAffineX(), 32), semSinal(k.getW().getAffineY(), 32));
    }

    private static byte[] semSinal(BigInteger v, int tamanho) {
        byte[] b = v.toByteArray();
        if (b.length == tamanho) return b;
        byte[] out = new byte[tamanho];
        if (b.length > tamanho) System.arraycopy(b, b.length - tamanho, out, 0, tamanho);
        else System.arraycopy(b, 0, out, tamanho - b.length, b.length);
        return out;
    }

    private static byte[] hmac(byte[] chave, byte[] dados) throws GeneralSecurityException {
        Mac m = Mac.getInstance("HmacSHA256");
        m.init(new SecretKeySpec(chave, "HmacSHA256"));
        return m.doFinal(dados);
    }

    private static byte[] concat(byte[]... partes) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        for (byte[] p : partes) out.writeBytes(p);
        return out.toByteArray();
    }

    static String b64(byte[] b) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }

    static byte[] b64d(String s) {
        return Base64.getUrlDecoder().decode(s.trim().replace('+', '-').replace('/', '_').replace("=", ""));
    }

    private static ECParameterSpec parametrosP256() {
        try {
            AlgorithmParameters p = AlgorithmParameters.getInstance("EC");
            p.init(new ECGenParameterSpec("secp256r1"));
            return p.getParameterSpec(ECParameterSpec.class);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
