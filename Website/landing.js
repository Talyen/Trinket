(() => {
  // Automatic launch-day flip on December 21, 2026 (local date) or ?launched=1 preview
  const now = new Date();
  const launched =
    now.getFullYear() > 2026 ||
    (now.getFullYear() === 2026 && (now.getMonth() > 11 || (now.getMonth() === 11 && now.getDate() >= 21))) ||
    new URLSearchParams(window.location.search).get("launched") === "1";

  if (launched) {
    for (const img of document.querySelectorAll("[data-launch-badge]")) {
      img.src = img.dataset.launchBadge;
      img.alt = "Download on the App Store";
      img.width = 120;
      img.height = 40;
    }
    for (const el of document.querySelectorAll("[data-launch-text]")) {
      el.textContent = el.dataset.launchText;
    }
  }

  // Header scroll separation
  const header = document.querySelector("[data-header]");
  if (header) {
    const syncHeader = () => {
      header.classList.toggle("is-scrolled", window.scrollY > 18);
    };
    syncHeader();
    window.addEventListener("scroll", syncHeader, { passive: true });
  }

  // Trailer player and interactive chapter seeking
  const player = document.querySelector("[data-trailer-player]");
  if (player) {
    const video = player.querySelector("video");
    const playButton = player.querySelector(".video-play");
    const chapters = [...document.querySelectorAll(".chapter-list [data-seek]")];

    if (video && playButton) {
      video.controls = false;
      playButton.hidden = false;
      const startPlayback = () => {
        video.controls = true;
        video.focus({ preventScroll: true });
        video.play().catch(() => video.focus());
      };
      playButton.addEventListener("click", startPlayback);
      video.addEventListener("click", () => {
        if (!video.controls) startPlayback();
      });
      video.addEventListener("playing", () => {
        video.controls = true;
        playButton.hidden = true;
      });
      video.addEventListener("ended", () => {
        playButton.hidden = false;
      });
    }

    if (video && chapters.length) {
      for (const chapter of chapters) {
        chapter.addEventListener("click", (event) => {
          if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
          event.preventDefault();
          video.controls = true;
          video.currentTime = Number(chapter.dataset.seek);
          video.play().catch(() => video.focus());
          video.focus({ preventScroll: true });
          player.scrollIntoView({ block: "nearest" });
        });
      }

      const markChapter = () => {
        const active = chapters.findLast(
          (chapter) => Number(chapter.dataset.seek) <= video.currentTime
        );
        for (const chapter of chapters) {
          if (chapter === active) chapter.setAttribute("aria-current", "time");
          else chapter.removeAttribute("aria-current");
        }
      };
      video.addEventListener("seeked", markChapter);
      video.addEventListener("timeupdate", markChapter);
    }
  }

  // Accessible segmented tabs for screenshot categories
  const tablist = document.querySelector('[role="tablist"]');
  if (tablist) {
    const tabs = [...tablist.querySelectorAll('[role="tab"]')];
    const activateTab = (nextTab, moveFocus = false) => {
      for (const tab of tabs) {
        const selected = tab === nextTab;
        tab.setAttribute("aria-selected", String(selected));
        tab.tabIndex = selected ? 0 : -1;
        const panel = document.getElementById(tab.getAttribute("aria-controls"));
        if (panel) panel.hidden = !selected;
      }
      if (moveFocus) nextTab.focus();
    };

    for (const tab of tabs) {
      tab.addEventListener("click", () => activateTab(tab));
    }

    tablist.addEventListener("keydown", (event) => {
      const index = tabs.indexOf(document.activeElement);
      if (index === -1) return;
      if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
        event.preventDefault();
        const delta = event.key === "ArrowRight" ? 1 : -1;
        activateTab(tabs[(index + delta + tabs.length) % tabs.length], true);
      } else if (event.key === "Home") {
        event.preventDefault();
        activateTab(tabs[0], true);
      } else if (event.key === "End") {
        event.preventDefault();
        activateTab(tabs[tabs.length - 1], true);
      }
    });
  }

  // Native modal screenshot lightbox with closedby="any" + Safari fallback
  const dialog = document.querySelector("#lightbox");
  if (dialog && typeof dialog.showModal === "function") {
    const photo = dialog.querySelector("[data-photo]");
    const captionEl = dialog.querySelector("[data-caption]");
    const countEl = dialog.querySelector("[data-count]");
    const closeBtn = dialog.querySelector("[data-close]");
    const prevBtn = dialog.querySelector("[data-prev]");
    const nextBtn = dialog.querySelector("[data-next]");
    let activeLinks = [];
    let current = 0;

    const show = (index) => {
      current = (index + activeLinks.length) % activeLinks.length;
      const link = activeLinks[current];
      const figure = link.closest("figure");
      const caption = figure?.querySelector("figcaption")?.textContent ?? "";
      photo.src = link.href;
      photo.alt = link.querySelector("img")?.alt ?? caption;
      captionEl.textContent = caption;
      countEl.textContent = `${current + 1} / ${activeLinks.length}`;
      dialog.setAttribute("aria-label", `Screenshot ${current + 1} of ${activeLinks.length}: ${caption}`);
    };

    for (const link of document.querySelectorAll("[data-lightbox]")) {
      link.setAttribute("aria-haspopup", "dialog");
      link.addEventListener("click", (event) => {
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        event.preventDefault();
        const panel = link.closest('[role="tabpanel"]');
        activeLinks = panel
          ? [...panel.querySelectorAll("[data-lightbox]")]
          : [...document.querySelectorAll("[data-lightbox]")];
        show(activeLinks.indexOf(link));
        dialog.showModal();
      });
    }

    closeBtn?.addEventListener("click", () => dialog.close());
    prevBtn?.addEventListener("click", () => show(current - 1));
    nextBtn?.addEventListener("click", () => show(current + 1));

    dialog.addEventListener("keydown", (event) => {
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        event.preventDefault();
        show(current + (event.key === "ArrowLeft" ? -1 : 1));
      }
    });

    // Touch swipe navigation for mobile lightbox browsing
    const stage = dialog.querySelector(".lightbox-stage");
    let touchStart = null;
    stage?.addEventListener("touchstart", (event) => {
      touchStart = event.touches.length === 1 ? event.touches[0] : null;
    }, { passive: true });
    stage?.addEventListener("touchcancel", () => { touchStart = null; });
    stage?.addEventListener("touchend", (event) => {
      if (!touchStart || event.touches.length) return;
      const dx = event.changedTouches[0].clientX - touchStart.clientX;
      const dy = event.changedTouches[0].clientY - touchStart.clientY;
      touchStart = null;
      if (Math.abs(dx) > 48 && Math.abs(dx) > 1.5 * Math.abs(dy)) {
        show(current + (dx < 0 ? 1 : -1));
      }
    }, { passive: true });

    // Fallback light-dismiss for browsers without closedby="any" support (e.g. Safari)
    if (!("closedBy" in HTMLDialogElement.prototype)) {
      dialog.addEventListener("click", (event) => {
        if (event.target !== dialog) return;
        const rect = dialog.getBoundingClientRect();
        const isDialogContent =
          rect.top <= event.clientY &&
          event.clientY <= rect.top + rect.height &&
          rect.left <= event.clientX &&
          event.clientX <= rect.left + rect.width;
        if (isDialogContent) return;
        dialog.close();
      });
    }
  }
})();
