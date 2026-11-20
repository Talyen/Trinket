(() => {
  const viewer = document.querySelector("#screenshot-viewer");
  if (typeof viewer?.showModal !== "function") return;

  const links = [...document.querySelectorAll(".gallery figure a")];
  const stage = viewer.querySelector(".viewer-stage");
  const photo = stage.querySelector("img");
  const zoomButton = viewer.querySelector("[data-zoom]");
  let current = 0;
  let touchStart;

  function setZoom(actualSize) {
    stage.classList.toggle("actual-size", actualSize);
    zoomButton.textContent = actualSize ? "Fit to screen" : "Actual size";
    stage.scrollTo(0, 0);
    touchStart = null;
  }

  function show(index) {
    current = (index + links.length) % links.length;
    const link = links[current];
    setZoom(false);
    const caption = link.closest("figure").querySelector("figcaption").textContent;
    photo.alt = caption;
    viewer.setAttribute("aria-label", "Gameplay screenshot " + (current + 1) + " of " + links.length + ". " + caption);
    photo.src = link.href;
    viewer.querySelector("[data-count]").textContent = (current + 1) + " / " + links.length;
    viewer.querySelector(".viewer-caption").textContent = caption;
    viewer.querySelector("[data-download]").href = link.href;
  }

  links.forEach((link, index) => {
    link.setAttribute("aria-haspopup", "dialog");
    link.addEventListener("click", event => {
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      viewer.querySelector(".viewer-details").open = false;
      viewer.showModal();
      show(index);
    });
  });

  viewer.querySelector("[data-prev]").addEventListener("click", () => show(current - 1));
  viewer.querySelector("[data-next]").addEventListener("click", () => show(current + 1));
  viewer.querySelector("[data-close]").addEventListener("click", () => viewer.close());
  zoomButton.addEventListener("click", () => setZoom(!stage.classList.contains("actual-size")));
  viewer.addEventListener("keydown", event => {
    if (stage.classList.contains("actual-size")) return;
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      show(current + (event.key === "ArrowLeft" ? -1 : 1));
    }
  });

  stage.addEventListener("touchstart", event => {
    touchStart = event.touches.length === 1 && !stage.classList.contains("actual-size")
      ? event.touches[0] : null;
  }, { passive: true });
  stage.addEventListener("touchcancel", () => { touchStart = null; });
  stage.addEventListener("touchend", event => {
    if (!touchStart || event.touches.length) return;
    const dx = event.changedTouches[0].clientX - touchStart.clientX;
    const dy = event.changedTouches[0].clientY - touchStart.clientY;
    touchStart = null;
    if (Math.abs(dx) > 50 && Math.abs(dx) > 1.5 * Math.abs(dy)) show(current + (dx < 0 ? 1 : -1));
  }, { passive: true });
})();
