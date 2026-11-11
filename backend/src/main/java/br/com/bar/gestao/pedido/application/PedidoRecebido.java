package br.com.bar.gestao.pedido.application;

import java.math.BigDecimal;

/** Evento: um pedido novo do cardápio foi gravado (usado para avisar o bar por notificação push). */
public record PedidoRecebido(long numero, String clienteNome, String local, int itens, BigDecimal total) {
}
