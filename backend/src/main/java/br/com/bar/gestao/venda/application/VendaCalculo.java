package br.com.bar.gestao.venda.application;

import br.com.bar.gestao.shared.exception.NegocioException;
import br.com.bar.gestao.venda.domain.FormaPagamento;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Regras de cálculo da venda (valores em reais, 2 casas). */
public final class VendaCalculo {

    private VendaCalculo() {
    }

    public static BigDecimal valor(BigDecimal unitario, BigDecimal quantidade) {
        return unitario.multiply(quantidade).setScale(2, RoundingMode.HALF_UP);
    }

    /** Desconto em valor ou em percentual sobre o subtotal (um ou outro), entre zero e o subtotal. */
    public static BigDecimal desconto(BigDecimal subtotal, BigDecimal valor, BigDecimal percentual) {
        boolean temValor = valor != null && valor.signum() != 0;
        boolean temPercentual = percentual != null && percentual.signum() != 0;
        if (temValor && temPercentual) {
            throw new NegocioException("DESCONTO_INVALIDO", "Informe o desconto em valor ou em percentual, não os dois.");
        }
        BigDecimal desconto = temValor ? valor
                : temPercentual ? subtotal.multiply(percentual).divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        if (desconto.signum() < 0 || desconto.compareTo(subtotal) > 0) {
            throw new NegocioException("DESCONTO_INVALIDO", "O desconto deve estar entre zero e o subtotal da venda.");
        }
        return desconto.setScale(2, RoundingMode.HALF_UP);
    }

    /** Valor recebido e troco: só em dinheiro. Sem valor informado, considera o valor exato. */
    public static Recebimento recebimento(FormaPagamento forma, BigDecimal total, BigDecimal valorRecebido) {
        if (forma != FormaPagamento.DINHEIRO) {
            return new Recebimento(null, null);
        }
        BigDecimal recebido = valorRecebido == null ? total : valorRecebido.setScale(2, RoundingMode.HALF_UP);
        if (recebido.compareTo(total) < 0) {
            throw new NegocioException("VALOR_RECEBIDO_INSUFICIENTE",
                    "O valor recebido (" + recebido + ") é menor que o total da venda (" + total + ").");
        }
        return new Recebimento(recebido, recebido.subtract(total));
    }

    public record Recebimento(BigDecimal valorRecebido, BigDecimal troco) {
    }
}
