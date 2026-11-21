(() => {
  const player = document.querySelector('.premiere-player');
  const video = player.querySelector('video');
  const playButton = player.querySelector('button');
  const chapters = [...document.querySelectorAll('.premiere-guide [data-seek]')];

  playButton.hidden = false;
  playButton.addEventListener('click', () => {
    video.focus({ preventScroll: true });
    video.play().catch(() => video.focus());
  });
  video.addEventListener('playing', () => { playButton.hidden = true; });
  video.addEventListener('ended', () => { playButton.hidden = false; });

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
