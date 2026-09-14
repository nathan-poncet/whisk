(() => {
  const featureData = [
    { id: 'panel', title: 'Copied once.<br>Ready whenever.', description: 'The link, the image, the thought you nearly lost. Everything you copy lives in one beautiful panel, ready when you need it.', keys: ['⇧', '⌘', 'V'], hint: 'One shortcut. All your history.', caption: 'Text, links, images, files, colors, code. All welcome.' },
    { id: 'search', title: 'Less looking.<br>More finding.', description: 'That link from Safari? That snippet from Slack? Search by content, filter by app or type, and get straight to the thing you need.', query: 'app:safari', hint: 'A few letters. The right result.', caption: 'Combine a search with filters to narrow things down.' },
    { id: 'color', title: 'Know it<br>when you see it.', description: 'Colors become swatches. Links get a preview. Code gets highlighted. Recognize what you copied before you paste a thing.', keys: ['⏎'], hint: 'See it. Choose it. Paste it.', caption: 'Rich previews, with the icon of the app they came from.' },
    { id: 'stack', title: 'Collect once.<br>Paste in order.', description: 'A name, an email, an address. Queue up the pieces, then paste them one by one into any form. No more switching back and forth.', keys: ['⌥', '⌘', 'V'], hint: 'Queue with ⇧⏎. Paste the next with ⌥⌘V.', caption: 'Your paste stack turns a dozen trips into one.' },
    { id: 'preview', title: 'The whole picture.<br>One keystroke.', description: 'A tiny card doesn’t always tell the whole story. Open a full-size preview for the complete text, the entire image, or every file.', keys: ['⌘', 'Y'], hint: 'A familiar shortcut. A closer look.', caption: 'Press again, or Escape, to return to your clipboard.' },
    { id: 'drag', title: 'Pick it up.<br>Drop it in.', description: 'An image into Mail. A file into Finder. A quote into your document. Drag a card straight into the app you’re working in.', query: 'drag → drop', hint: 'Right from the panel into your work.', caption: 'Whisk floats over your apps. Your destination is in reach.' },
  ];
  const byId = (id) => document.getElementById(id);
  const tabs = [...document.querySelectorAll('[data-feature]')];
  const panel = byId('feature-panel');
  const media = byId('feature-media');
  const video = byId('feature-video');
  const poster = byId('feature-poster');
  const playButton = byId('feature-play');
  const progress = byId('feature-progress');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  let selected = 0;
  let inView = false;
  let manuallyPaused = false;
  let hasSource = false;

  const updatePlayButton = () => {
    const paused = video.paused;
    playButton.innerHTML = `<span aria-hidden="true">${paused ? '▶' : 'Ⅱ'}</span> ${paused ? 'Play' : 'Pause'}`;
    playButton.setAttribute('aria-label', `${paused ? 'Play' : 'Pause'} ${tabs[selected].textContent.trim()} demonstration`);
  };
  const ensureSource = () => {
    if (hasSource) return;
    video.src = `media/clips/${featureData[selected].id}.mp4`;
    video.load();
    hasSource = true;
  };
  const play = () => {
    ensureSource();
    video.play().catch(updatePlayButton);
  };
  const selectFeature = (index, byUser = false) => {
    if (selected === index && hasSource) return;
    video.pause();
    selected = index;
    const feature = featureData[index];
    tabs.forEach((tab, n) => {
      tab.setAttribute('aria-selected', String(n === index));
      tab.tabIndex = n === index ? 0 : -1;
    });
    panel.setAttribute('aria-labelledby', tabs[index].id);
    byId('feature-index').textContent = `${String(index + 1).padStart(2, '0')} / 06`;
    byId('feature-title').innerHTML = feature.title;
    byId('feature-description').textContent = feature.description;
    byId('feature-caption').textContent = feature.caption;
    byId('feature-shortcut').innerHTML = '<div>' + (feature.keys ? feature.keys.map((key) => `<kbd>${key}</kbd>`).join('') : `<code>${feature.query}</code>`) + `</div><span>${feature.hint}</span>`;
    video.setAttribute('aria-label', `${tabs[index].textContent.trim()} demonstration`);
    media.classList.remove('is-playing');
    poster.src = `media/clips/${feature.id}.jpg`;
    poster.alt = `Whisk ${tabs[index].textContent.trim().toLowerCase()} on macOS`;
    progress.style.transform = 'scaleX(0)';
    hasSource = false;
    // Selecting a tab updates its still image; reduced motion always requires Play.
    if (byUser) manuallyPaused = false;
    if (inView && !motion.matches && !manuallyPaused) play();
    updatePlayButton();
  };
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectFeature(index, true));
    tab.addEventListener('keydown', (event) => {
      const next = { ArrowRight: (index + 1) % tabs.length, ArrowLeft: (index + tabs.length - 1) % tabs.length, Home: 0, End: tabs.length - 1 }[event.key];
      if (next === undefined) return;
      event.preventDefault();
      selectFeature(next, true);
      tabs[next].focus({ preventScroll: true });
    });
  });
  playButton.addEventListener('click', () => {
    if (video.paused) { manuallyPaused = false; play(); }
    else { manuallyPaused = true; video.pause(); }
  });
  video.addEventListener('playing', () => media.classList.add('is-playing'));
  video.addEventListener('play', updatePlayButton);
  video.addEventListener('pause', updatePlayButton);
  video.addEventListener('timeupdate', () => {
    progress.style.transform = `scaleX(${video.duration ? video.currentTime / video.duration : 0})`;
  });
  video.addEventListener('error', () => {
    media.classList.remove('is-playing');
    byId('feature-caption').textContent = 'Video unavailable. You can still explore this feature in the playground.';
    updatePlayButton();
  });
  const resumeIfVisible = () => {
    if (!document.hidden && inView && !motion.matches && !manuallyPaused) play();
    else video.pause();
  };
  new IntersectionObserver(([entry]) => {
    inView = entry.isIntersecting;
    resumeIfVisible();
  }, { threshold: 0.25 }).observe(media);
  document.addEventListener('visibilitychange', resumeIfVisible);
  motion.addEventListener('change', resumeIfVisible);
  selectFeature(0);

  document.querySelectorAll('[data-key-mode]').forEach((button) => {
    button.addEventListener('click', () => {
      const vim = button.dataset.keyMode === 'vim';
      document.querySelectorAll('[data-key-mode]').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
      byId('feature-keycaps').innerHTML = (vim ? ['h', 'j', 'k', 'l'] : ['←', '↓', '↑', '→']).map((key) => `<kbd>${key}</kbd>`).join('');
      byId('feature-key-hint').textContent = vim ? 'hjkl to explore. p to paste. / to search.' : 'Arrow keys to explore. Return to paste.';
    });
  });
  document.querySelectorAll('button[data-format]').forEach((button) => {
    button.addEventListener('click', () => {
      byId('feature-format').dataset.format = button.dataset.format;
      document.querySelectorAll('button[data-format]').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
    });
  });
  byId('pin-clear').addEventListener('click', () => {
    const cleared = byId('feature-pins').classList.toggle('is-cleared');
    byId('pin-clear').textContent = cleared ? 'Reset demo ↺' : 'Clear history ↗';
    byId('pin-clear').setAttribute('aria-label', cleared ? 'Reset the sample history' : 'Clear the sample history');
    byId('pin-feedback').textContent = cleared ? 'Cleared. Pin kept.' : 'Your pins stay.';
  });
})();
