// 为 MkDocs Material 渲染的 Mermaid 图表增加「放大 / 缩小 / 复位」与拖拽平移。
// 零外部依赖：不引入 svg-pan-zoom 等 CDN，离线也可使用。
(function () {
  'use strict';

  function setup(container) {
    if (container.dataset.zoomReady) return;
    var svg = container.querySelector('svg');
    if (!svg) return;
    container.dataset.zoomReady = '1';

    var scale = 1, tx = 0, ty = 0;

    function apply() {
      svg.style.transformOrigin = '0 0';
      svg.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')';
      svg.style.cursor = 'grab';
    }
    apply();

    function makeButton(label, title, fn) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      b.title = title;
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        fn();
      });
      return b;
    }

    var toolbar = document.createElement('div');
    toolbar.className = 'mermaid-zoom-toolbar';
    toolbar.appendChild(makeButton('＋', '放大', function () {
      scale = Math.min(scale * 1.2, 6);
      apply();
    }));
    toolbar.appendChild(makeButton('－', '缩小', function () {
      scale = Math.max(scale / 1.2, 0.3);
      apply();
    }));
    toolbar.appendChild(makeButton('⟲', '复位', function () {
      scale = 1; tx = 0; ty = 0; apply();
    }));
    container.appendChild(toolbar);

    var dragging = false, lastX = 0, lastY = 0;
    svg.addEventListener('mousedown', function (e) {
      dragging = true;
      lastX = e.clientX;
      lastY = e.clientY;
      svg.style.cursor = 'grabbing';
      e.preventDefault();
    });
    window.addEventListener('mousemove', function (e) {
      if (!dragging) return;
      tx += e.clientX - lastX;
      ty += e.clientY - lastY;
      lastX = e.clientX;
      lastY = e.clientY;
      apply();
    });
    window.addEventListener('mouseup', function () {
      dragging = false;
      svg.style.cursor = 'grab';
    });
  }

  function observe() {
    var containers = document.querySelectorAll('.mermaid');
    Array.prototype.forEach.call(containers, function (c) {
      if (c.querySelector('svg')) {
        setup(c);
      } else {
        var mo = new MutationObserver(function () {
          if (c.querySelector('svg')) {
            mo.disconnect();
            setup(c);
          }
        });
        mo.observe(c, { childList: true, subtree: true });
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observe);
  } else {
    observe();
  }
})();
