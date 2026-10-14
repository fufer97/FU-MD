(function () {
  'use strict';

  var vditor = null;
  var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  var notifyTimer = null;

  function post(msg) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.fumd) {
      window.webkit.messageHandlers.fumd.postMessage(msg);
    }
  }

  function themeName(isDark) { return isDark ? 'dark' : 'light'; }

  function headingNodes() {
    return document.querySelectorAll('#editor .vditor-ir__node[data-type="heading"]');
  }

  function collectOutline() {
    var nodes = headingNodes();
    var items = [];
    nodes.forEach(function (n, i) {
      var marker = n.querySelector('.vditor-ir__marker--heading');
      var hashes = marker ? (marker.textContent.match(/#/g) || []).length : 1;
      var clone = n.cloneNode(true);
      clone.querySelectorAll('.vditor-ir__marker').forEach(function (m) { m.remove(); });
      items.push({
        index: i,
        level: Math.min(6, Math.max(1, hashes)),
        text: (clone.textContent || '').trim()
      });
    });
    return items;
  }

  // Vditor 4 移除了 getStatistics，这里自行统计（CJK 每个字算一个词）
  function computeStats(value) {
    var lines = value ? value.split('\n').length : 0;
    var cjk = (value.match(/[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]/g) || []).length;
    var latin = (value.match(/[A-Za-z0-9][A-Za-z0-9'’\-_]*/g) || []).length;
    var characters = (value.replace(/\s/g, '')).length;
    return { characters: characters, words: cjk + latin, lines: lines };
  }

  function notifyChange() {
    if (!vditor) return;
    var value = vditor.getValue();
    post({ type: 'contentChanged', markdown: value, stats: computeStats(value) });
    post({ type: 'outline', items: collectOutline() });
  }

  function scheduleNotify() {
    clearTimeout(notifyTimer);
    notifyTimer = setTimeout(notifyChange, 300);
  }

  function applyTheme(isDark) {
    dark = isDark;
    document.documentElement.style.background = isDark ? '#1e1e1e' : '#ffffff';
    document.body.style.background = isDark ? '#1e1e1e' : '#ffffff';
    if (vditor) {
      vditor.setTheme(themeName(isDark), themeName(isDark), isDark ? 'github-dark' : 'github');
    }
  }

  // Vditor 的 getHTML() 对公式只给出原始源码（<span|div class="language-math">），
  // 导出的 HTML/PDF 里因此显示的是 LaTeX 源码。导出前在这里用全局 katex 补一次排版，
  // 行内/独立公式按节点是 span 还是 div 区分；渲染失败就保留原始源码，不阻断导出。
  function renderMath(html) {
    if (!html || typeof katex === 'undefined') return html;
    var box = document.createElement('div');
    box.innerHTML = html;
    var nodes = box.querySelectorAll('.language-math');
    if (!nodes.length) return html;
    nodes.forEach(function (node) {
      var source = (node.textContent || '').trim();
      if (!source) return;
      try {
        katex.render(source, node, { displayMode: node.tagName === 'DIV', throwOnError: false });
      } catch (e) { /* 保留原始源码 */ }
    });
    return box.innerHTML;
  }

  window.FUMDBridge = {
    init: function (payload) {
      if (typeof payload === 'string') {
        try { payload = JSON.parse(payload); } catch (e) { payload = {}; }
      }
      payload = payload || {};
      if (typeof payload.dark === 'boolean') { dark = payload.dark; }

      vditor = new Vditor('editor', {
        mode: 'ir',
        value: payload.markdown || '',
        cache: { enable: false },
        cdn: 'vditor',
        lang: 'zh_CN',
        theme: themeName(dark),
        toolbar: [],
        typewriterMode: false,
        placeholder: '开始输入 Markdown，即刻呈现…',
        height: '100%',
        preview: {
          theme: { current: themeName(dark), path: 'vditor/dist/css/content-theme' },
          hljs: { enable: true, style: dark ? 'github-dark' : 'github', lineNumber: false },
          math: { engine: 'KaTeX' }
        },
        after: function () {
          applyTheme(dark);
          post({ type: 'ready' });
        },
        input: function () { scheduleNotify(); }
      });
    },
    setValue: function (payload) {
      if (!vditor) return;
      if (typeof payload === 'string') {
        try { payload = JSON.parse(payload); } catch (e) { payload = {}; }
      }
      vditor.setValue((payload && payload.markdown) || '');
      scheduleNotify();
    },
    getValue: function () {
      return vditor ? vditor.getValue() : '';
    },
    getHtml: function () {
      return vditor ? renderMath(vditor.getHTML()) : '';
    },
    setTheme: function (isDark) {
      applyTheme(!!isDark);
    },
    focus: function () {
      if (vditor) { vditor.focus(); }
    },
    requestOutline: function () {
      post({ type: 'outline', items: collectOutline() });
    },
    scrollToHeading: function (index) {
      var node = headingNodes()[index];
      if (node) { node.scrollIntoView({ block: 'start', behavior: 'smooth' }); }
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      window.FUMDBridge.init({});
    });
  } else {
    window.FUMDBridge.init({});
  }
})();
