package br.com.bar.gestao.auth.application;

import br.com.bar.gestao.auth.domain.Usuario;
import br.com.bar.gestao.auth.domain.UsuarioRepository;
import br.com.bar.gestao.shared.security.SecurityProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Garante, na inicialização, que o usuário administrativo fixo exista com a senha definida
 * em ADMIN_LOGIN / ADMIN_PASSWORD. A senha é guardada somente como hash BCrypt.
 * Trocar a variável de ambiente e reiniciar o backend troca a senha.
 */
@Component
public class AdminBootstrap implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrap.class);
    private static final int TAMANHO_MINIMO_SENHA = 8;

    private final UsuarioRepository repository;
    private final PasswordEncoder encoder;
    private final SecurityProperties props;

    public AdminBootstrap(UsuarioRepository repository, PasswordEncoder encoder, SecurityProperties props) {
        this.repository = repository;
        this.encoder = encoder;
        this.props = props;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        String login = props.adminLogin();
        String senha = props.adminPassword();
        if (login == null || login.isBlank() || senha == null || senha.isBlank()) {
            throw new IllegalStateException("ADMIN_LOGIN e ADMIN_PASSWORD devem ser configurados (ver .env.example).");
        }
        if (senha.length() < TAMANHO_MINIMO_SENHA) {
            throw new IllegalStateException("ADMIN_PASSWORD deve ter ao menos " + TAMANHO_MINIMO_SENHA + " caracteres.");
        }
        repository.findByLogin(login.trim()).ifPresentOrElse(usuario -> {
            if (!encoder.matches(senha, usuario.getSenhaHash())) {
                usuario.alterarSenhaHash(encoder.encode(senha));
                log.info("Senha do usuário administrativo '{}' atualizada a partir do ambiente.", usuario.getLogin());
            }
            usuario.ativar();
        }, () -> {
            repository.save(new Usuario(login.trim(), encoder.encode(senha)));
            log.info("Usuário administrativo '{}' criado.", login.trim());
        });
    }
}
