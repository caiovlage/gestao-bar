// Ponte entre o painel (Flutter) e a API de notificações do navegador.
// O Dart chama window.entreNosPush.* e recebe strings (promessas).
(function () {
  'use strict';
  var SW = 'push-sw.js';

  function suportado() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  function ehIos() {
    return /iPhone|iPad|iPod/.test(navigator.userAgent);
  }

  function instaladoNaTela() {
    return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  }

  function base64ParaBytes(b64) {
    var pad = '='.repeat((4 - (b64.length % 4)) % 4);
    var bin = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'));
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function registro() {
    return navigator.serviceWorker.getRegistration('./');
  }

  function inscricaoAtual() {
    return registro().then(function (reg) {
      return reg ? reg.pushManager.getSubscription() : null;
    });
  }

  // Instalação do app (Android/computador): o navegador avisa que dá para instalar; guardamos o
  // evento para o botão "Instalar o app" do painel. No iPhone não existe: é pelo Compartilhar.
  var pedidoInstalacao = null;
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    pedidoInstalacao = e;
  });
  window.addEventListener('appinstalled', function () {
    pedidoInstalacao = null;
  });

  window.entreNosPush = {
    /** inseguro | ios-instalar | nao-suportado | bloqueado | inativo | ativo */
    estado: function () {
      if (!window.isSecureContext) return Promise.resolve('inseguro');
      if (!suportado()) return Promise.resolve(ehIos() && !instaladoNaTela() ? 'ios-instalar' : 'nao-suportado');
      if (Notification.permission === 'denied') return Promise.resolve('bloqueado');
      return inscricaoAtual().then(function (sub) {
        return sub ? 'ativo' : 'inativo';
      }).catch(function () {
        return 'inativo';
      });
    },

    /** Pede permissão, inscreve e devolve a inscrição em JSON (ou {"erro": ...}). */
    ativar: function (chavePublica) {
      return Notification.requestPermission().then(function (permissao) {
        if (permissao !== 'granted') {
          return JSON.stringify({ erro: permissao === 'denied' ? 'bloqueado' : 'recusado' });
        }
        return navigator.serviceWorker.register(SW, { scope: './' })
          .then(function () { return navigator.serviceWorker.ready; })
          .then(function (reg) {
            return reg.pushManager.getSubscription().then(function (sub) {
              return sub || reg.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: base64ParaBytes(chavePublica),
              });
            });
          })
          .then(function (sub) { return JSON.stringify(sub.toJSON()); })
          .catch(function (e) { return JSON.stringify({ erro: String(e && e.message || e) }); });
      });
    },

    /** Cancela a inscrição deste aparelho e devolve o endpoint cancelado ('' se não havia). */
    desativar: function () {
      return inscricaoAtual().then(function (sub) {
        if (!sub) return '';
        var endpoint = sub.endpoint;
        return sub.unsubscribe().then(function () { return endpoint; });
      }).catch(function () { return ''; });
    },

    endpoint: function () {
      return inscricaoAtual().then(function (sub) { return sub ? sub.endpoint : ''; }).catch(function () { return ''; });
    },

    /** instalado | sim (pode instalar agora) | ios (Compartilhar → Adicionar à Tela de Início) | nao */
    instalacao: function () {
      if (instaladoNaTela()) return Promise.resolve('instalado');
      if (pedidoInstalacao) return Promise.resolve('sim');
      return Promise.resolve(ehIos() ? 'ios' : 'nao');
    },

    /** Abre a instalação nativa do navegador; devolve accepted | dismissed | indisponivel. */
    instalar: function () {
      if (!pedidoInstalacao) return Promise.resolve('indisponivel');
      var p = pedidoInstalacao;
      pedidoInstalacao = null;
      return p.prompt().then(function () { return p.userChoice; })
        .then(function (r) { return r.outcome; })
        .catch(function () { return 'indisponivel'; });
    },

    /** Nome amigável do aparelho (ex.: "Android · Chrome"). */
    nomeAparelho: function () {
      var ua = navigator.userAgent;
      var so = /Android/.test(ua) ? 'Android' : ehIos() ? 'iPhone/iPad' : /Windows/.test(ua) ? 'Windows'
        : /Mac OS/.test(ua) ? 'Mac' : /Linux/.test(ua) ? 'Linux' : 'Aparelho';
      var nav = /Edg\//.test(ua) ? 'Edge' : /OPR\//.test(ua) ? 'Opera' : /Firefox\//.test(ua) ? 'Firefox'
        : /SamsungBrowser/.test(ua) ? 'Samsung Internet' : /Chrome\//.test(ua) ? 'Chrome'
        : /Safari\//.test(ua) ? 'Safari' : 'Navegador';
      return so + ' · ' + nav;
    },
  };

  // Mantém o service worker registrado e atualizado (substitui o antigo cache do Flutter).
  if (window.isSecureContext && suportado()) {
    navigator.serviceWorker.register(SW, { scope: './' }).catch(function () {});
  }
})();
