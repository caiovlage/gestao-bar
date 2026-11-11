package br.com.bar.gestao.shared.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

/** Tarefas em segundo plano (ex.: envio de notificações push sem atrasar o pedido do cliente). */
@Configuration
@EnableAsync
public class AsyncConfig {
}
