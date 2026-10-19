// Nav scroll state
const nav = document.getElementById('nav');
const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 12);
window.addEventListener('scroll', onScroll, { passive: true });
onScroll();

// Mobile nav toggle
const toggle = document.getElementById('navToggle');
const links = document.getElementById('navLinks');
toggle.addEventListener('click', () => {
  toggle.classList.toggle('open');
  links.classList.toggle('open');
});
links.querySelectorAll('a').forEach(a =>
  a.addEventListener('click', () => {
    toggle.classList.remove('open');
    links.classList.remove('open');
  })
);

// Scroll reveal
const revealObserver = new IntersectionObserver(
  entries => entries.forEach(e => {
    if (e.isIntersecting) {
      e.target.classList.add('visible');
      revealObserver.unobserve(e.target);
    }
  }),
  { threshold: 0.12 }
);
document.querySelectorAll('.reveal').forEach(el => revealObserver.observe(el));

document.querySelectorAll('.step, .card, .mod, .faq-item, .strip-item, .spot, .bento-card, .price-card, .cmp-wrap, .cutout').forEach((el, i) => {
  el.classList.add('reveal');
  el.style.transitionDelay = `${(i % 6) * 45}ms`;
  revealObserver.observe(el);
});

// Annual / Monthly billing toggle
const billBtns = document.querySelectorAll('.bill-btn');
const priceNums = document.querySelectorAll('.price-num');
const priceSubs = document.querySelectorAll('.price-sub');

billBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    const period = btn.dataset.period;
    billBtns.forEach(b => b.classList.toggle('active', b === btn));
    priceNums.forEach(n => {
      n.textContent = n.dataset[period];
    });
    priceSubs.forEach((s, idx) => {
      if (idx < 2) {
        s.textContent = period === 'annual' ? 'Billed annually · GST extra' : 'Billed monthly · GST extra';
      }
    });
  });
});

// Lightbox zoom on any screenshot frame
const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightboxImg');
const lightboxClose = document.getElementById('lightboxClose');

const openZoom = src => {
  if (!src) return;
  lightboxImg.src = src;
  lightbox.classList.add('open');
  lightbox.setAttribute('aria-hidden', 'false');
};
const closeZoom = () => {
  lightbox.classList.remove('open');
  lightbox.setAttribute('aria-hidden', 'true');
};

document.querySelectorAll('[data-zoom]').forEach(el => {
  el.addEventListener('click', () => openZoom(el.dataset.zoom));
});
lightbox.addEventListener('click', closeZoom);
lightboxClose.addEventListener('click', closeZoom);
window.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeZoom();
});
