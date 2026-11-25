(() => {
  const now = new Date();
  const launched =
    now.getFullYear() > 2026 ||
    (now.getFullYear() === 2026 && (now.getMonth() > 11 || (now.getMonth() === 11 && now.getDate() >= 21))) ||
    new URLSearchParams(window.location.search).get("launched") === "1";
  if (launched) {
    for (const img of document.querySelectorAll('[data-launch-badge]')) {
      img.src = img.dataset.launchBadge;
      img.alt = 'Download on the App Store';
      img.width = 120;
      img.height = 40;
    }
  }

  const player = document.querySelector('.premiere-player');
  const video = player.querySelector('video');
  const chapters = [...document.querySelectorAll('.premiere-guide [data-seek]')];

  const videos = [...document.querySelectorAll('.phone-player video')];
  for (const clip of videos) {
    const playButton = clip.parentElement.querySelector('button');
    playButton.hidden = false;
    playButton.addEventListener('click', () => {
      clip.focus({ preventScroll: true });
      clip.play().catch(() => clip.focus());
    });
    clip.addEventListener('play', () => {
      for (const other of videos) {
        if (other !== clip && !other.paused) other.pause();
      }
    });
    clip.addEventListener('playing', () => { playButton.hidden = true; });
    clip.addEventListener('ended', () => { playButton.hidden = false; });
  }

  for (const chapter of chapters) {
    chapter.addEventListener('click', event => {
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      video.currentTime = Number(chapter.dataset.seek);
      video.play().catch(() => video.focus());
      video.focus({ preventScroll: true });
      player.scrollIntoView({ block: 'nearest' });
    });
  }

  const markChapter = () => {
    const active = chapters.findLast(chapter => Number(chapter.dataset.seek) <= video.currentTime);
    for (const chapter of chapters) {
      if (chapter === active) chapter.setAttribute('aria-current', 'time');
      else chapter.removeAttribute('aria-current');
    }
  };
  video.addEventListener('seeked', markChapter);
  video.addEventListener('timeupdate', markChapter);
})();
