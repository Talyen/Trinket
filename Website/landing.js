(() => {
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
      playButton.hidden = false;
      playButton.addEventListener("click", () => {
        video.focus({ preventScroll: true });
        video.play().catch(() => video.focus());
      });
      video.addEventListener("playing", () => {
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
