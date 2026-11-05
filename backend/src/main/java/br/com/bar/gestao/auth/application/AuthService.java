package br.com.bar.gestao.auth.application;

import br.com.bar.gestao.auth.domain.Usuario;
import br.com.bar.gestao.auth.domain.UsuarioRepository;
import br.com.bar.gestao.shared.exception.AutenticacaoException;
import br.com.bar.gestao.shared.security.JwtService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UsuarioRepository repository;
    private final PasswordEncoder encoder;
    private final JwtService jwtService;
    /** Hash usado quando o login não existe, para que o tempo de resposta não revele usuários válidos. */
    private final String hashFalso;

    public AuthService(UsuarioRepository repository, PasswordEncoder encoder, JwtService jwtService) {
        this.repository = repository;
        this.encoder = encoder;
        this.jwtService = jwtService;
        this.hashFalso = encoder.encode("senha-inexistente-para-tempo-constante");
    }

    @Transactional(readOnly = true)
    public JwtService.TokenEmitido login(String login, String senha) {
        Optional<Usuario> usuario = repository.findByLogin(login.trim()).filter(Usuario::isAtivo);
        boolean senhaOk = encoder.matches(senha, usuario.map(Usuario::getSenhaHash).orElse(hashFalso));
        if (usuario.isEmpty() || !senhaOk) {
            log.warn("Tentativa de login inválida para '{}'", login);
            throw new AutenticacaoException("Login ou senha inválidos.");
        }
        log.info("Login realizado: {}", usuario.get().getLogin());
        return jwtService.emitir(usuario.get().getLogin());
    }
}
