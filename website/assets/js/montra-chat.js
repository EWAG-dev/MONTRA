// MONTRA Team concierge chat ("Maya"). A self-injecting, dependency-free widget
// added to every public page. It feels like a human concierge team — never an "AI
// bot" — and its primary objective is to drive consultation bookings. "Talk to a
// Human" opens a callback request form that creates a routed lead in the backend.
//
// Include with: <script type="module" src="assets/js/montra-chat.js"></script>

(() => {
  if (window.__montraChat) return;
  window.__montraChat = true;

  const BACKEND_URL = 'https://montra-production.up.railway.app';

  // Where is the visitor? Drives lead priority routing on the backend.
  function detectSource() {
    const p = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    if (p.includes('coach-profile')) return 'coach_profile';
    if (p.includes('pricing')) return 'pricing';
    if (p.includes('quiz') || p.includes('consult')) return 'consultation';
    if (p.includes('how-it-works')) return 'how_it_works';
    if (p.includes('services')) return 'services';
    if (p.includes('for-trainers') || p.includes('trainer-appl')) return 'coach_application';
    if (p === '' || p.includes('index') || p.includes('find-a-coach')) return 'homepage';
    return 'homepage';
  }
  const SOURCE = detectSource();
  const SOURCE_PATH = location.pathname + location.search;

  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[c]));

  const PERSON_SVG = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12a5 5 0 100-10 5 5 0 000 10zm0 2c-4 0-8 2-8 5v1h16v-1c0-3-4-5-8-5z"/></svg>';
  // Maya's headshot. Lives in website/public/ so it's served verbatim at the root.
  // Drop a licensed real photo at website/public/maya.jpg and point this at it
  // ('/maya.jpg'); if the image fails to load we fall back to the SVG glyph.
  const MAYA_IMG = '/maya.svg';
  // Avatar inner content: real photo on top, glyph beneath as a graceful fallback.
  const AV = `<img class="mtc-photo" src="${MAYA_IMG}" alt="Maya" onerror="this.remove()"/>${PERSON_SVG}`;
  const GUARANTEE = 'Every client is protected by the MONTRA Match Guarantee™. If your coach isn’t the right fit, MONTRA will work with you to identify another qualified coach who better aligns with your goals, preferences, and coaching needs.';

  // ---- Styles (self-contained, scoped with .mtc-) ----------------------------
  const style = document.createElement('style');
  style.textContent = `
  .mtc-launch{position:fixed;right:20px;bottom:20px;z-index:99998;display:flex;align-items:center;gap:10px;background:#0b0b0c;color:#fff;border:1.5px solid #E85D04;border-radius:9999px;padding:9px 18px 9px 9px;font:600 14px/1 Inter,system-ui,sans-serif;cursor:pointer;box-shadow:0 10px 30px rgba(0,0,0,.35);transition:transform .15s,box-shadow .15s}
  .mtc-launch:hover{transform:translateY(-2px);box-shadow:0 14px 36px rgba(232,93,4,.35)}
  .mtc-launch.hide{display:none}
  .mtc-av{position:relative;border-radius:9999px;background:linear-gradient(135deg,#2a2a2e,#0b0b0c);border:2px solid #E85D04;color:#E85D04;display:flex;align-items:center;justify-content:center;flex-shrink:0;overflow:hidden}
  .mtc-av svg{width:62%;height:62%}
  .mtc-photo{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
  .mtc-dot{position:absolute;right:-1px;bottom:-1px;width:10px;height:10px;border-radius:9999px;background:#22c55e;border:2px solid #0b0b0c}
  .mtc-panel{position:fixed;right:20px;bottom:20px;z-index:99999;width:374px;max-width:calc(100vw - 32px);height:600px;max-height:calc(100vh - 40px);background:#0b0b0c;border:1px solid #232327;border-radius:20px;display:none;flex-direction:column;overflow:hidden;box-shadow:0 24px 60px rgba(0,0,0,.5);font-family:Inter,system-ui,sans-serif;color:#fff}
  .mtc-panel.open{display:flex;animation:mtcIn .22s ease}
  @keyframes mtcIn{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:none}}
  .mtc-head{display:flex;align-items:center;gap:11px;padding:14px 16px;background:#0b0b0c;border-bottom:1px solid #1c1c20}
  .mtc-head .mtc-av{width:42px;height:42px}
  .mtc-head h4{margin:0;font-size:15px;font-weight:800;display:flex;align-items:center;gap:6px}
  .mtc-head .sub{font-size:11px;color:#9aa0a6;margin-top:1px}
  .mtc-head .online{width:7px;height:7px;border-radius:9999px;background:#22c55e;display:inline-block}
  .mtc-x{margin-left:auto;background:none;border:none;color:#9aa0a6;font-size:20px;cursor:pointer;line-height:1;padding:4px}
  .mtc-x:hover{color:#fff}
  .mtc-body{flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:12px;background:#0b0b0c}
  .mtc-body::-webkit-scrollbar{width:6px}.mtc-body::-webkit-scrollbar-thumb{background:#2a2a2e;border-radius:6px}
  .mtc-row{display:flex;gap:9px;align-items:flex-end}
  .mtc-row .mtc-av{width:30px;height:30px}
  .mtc-bubble{max-width:78%;padding:10px 13px;border-radius:14px;font-size:13.5px;line-height:1.5}
  .mtc-bubble.maya{background:#17171a;color:#e9eaeb;border-bottom-left-radius:4px}
  .mtc-bubble.user{background:#E85D04;color:#fff;margin-left:auto;border-bottom-right-radius:4px}
  .mtc-time{font-size:10px;color:#6b7077;text-align:center;margin:2px 0}
  .mtc-qa{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:2px}
  .mtc-qa-card{display:flex;gap:9px;align-items:flex-start;text-align:left;background:#141417;border:1px solid #232327;border-radius:12px;padding:10px;cursor:pointer;transition:border-color .15s,background .15s}
  .mtc-qa-card:hover{border-color:#E85D04;background:#1a1a1d}
  .mtc-qa-card .ic{font-size:16px;line-height:1}
  .mtc-qa-card .t{font-size:12px;font-weight:800;color:#fff}
  .mtc-qa-card .d{font-size:10.5px;color:#9aa0a6;margin-top:1px}
  .mtc-opts{display:flex;flex-wrap:wrap;gap:7px;margin-top:2px}
  .mtc-chip{background:#141417;border:1px solid #2f2f34;color:#e9eaeb;border-radius:9999px;padding:8px 13px;font-size:12.5px;font-weight:600;cursor:pointer;transition:all .15s}
  .mtc-chip:hover{border-color:#E85D04;color:#fff}
  .mtc-cta{display:block;width:100%;text-align:center;background:#E85D04;color:#fff;border:none;border-radius:11px;padding:12px;font-size:13.5px;font-weight:800;cursor:pointer;text-decoration:none;margin-top:4px;transition:background .15s}
  .mtc-cta:hover{background:#cf5104}
  .mtc-cta.ghost{background:transparent;border:1px solid #2f2f34;color:#e9eaeb}
  .mtc-cta.ghost:hover{border-color:#E85D04;color:#fff;background:#141417}
  .mtc-form{background:#141417;border:1px solid #232327;border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:9px}
  .mtc-form .fh{text-align:center;margin-bottom:2px}
  .mtc-form .fh .ph{width:46px;height:46px;border-radius:9999px;border:2px solid #E85D04;color:#E85D04;display:flex;align-items:center;justify-content:center;margin:0 auto 8px}
  .mtc-form .fh .ph svg{width:22px;height:22px}
  .mtc-form .fh h5{margin:0;font-size:15px;font-weight:800}
  .mtc-form .fh p{margin:3px 0 0;font-size:11.5px;color:#9aa0a6}
  .mtc-field{display:flex;align-items:center;gap:9px;background:#0b0b0c;border:1px solid #2f2f34;border-radius:10px;padding:10px 12px}
  .mtc-field svg{width:15px;height:15px;color:#6b7077;flex-shrink:0}
  .mtc-field input,.mtc-field select{flex:1;background:none;border:none;outline:none;color:#fff;font-size:13px;font-family:inherit}
  .mtc-field select{cursor:pointer}.mtc-field select option{background:#141417}
  .mtc-field input::placeholder{color:#6b7077}
  .mtc-err{color:#f87171;font-size:11.5px}
  .mtc-secure{font-size:10.5px;color:#6b7077;text-align:center;display:flex;align-items:center;justify-content:center;gap:5px}
  .mtc-conf{text-align:center;background:#141417;border:1px solid #232327;border-radius:14px;padding:22px 16px}
  .mtc-conf .ck{width:54px;height:54px;border-radius:9999px;background:#E85D04;color:#fff;display:flex;align-items:center;justify-content:center;margin:0 auto 12px;font-size:26px}
  .mtc-conf h5{margin:0 0 6px;font-size:17px;font-weight:800}
  .mtc-conf p{margin:0;font-size:12.5px;color:#c4c8cc;line-height:1.55}
  .mtc-conf .eta{color:#E85D04;font-weight:800}
  .mtc-foot{padding:10px 14px;border-top:1px solid #1c1c20;background:#0b0b0c}
  .mtc-inrow{display:flex;align-items:center;gap:8px;background:#141417;border:1px solid #232327;border-radius:12px;padding:6px 6px 6px 13px}
  .mtc-inrow input{flex:1;background:none;border:none;outline:none;color:#fff;font-size:13px;font-family:inherit}
  .mtc-inrow input::placeholder{color:#6b7077}
  .mtc-send{width:34px;height:34px;border-radius:9999px;background:#E85D04;border:none;color:#fff;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0}
  .mtc-send:hover{background:#cf5104}
  .mtc-reply{font-size:10.5px;color:#6b7077;text-align:center;margin-top:7px}
  @media (max-width:480px){.mtc-panel{right:8px;left:8px;bottom:8px;width:auto;height:calc(100vh - 16px);max-height:none}.mtc-launch{right:12px;bottom:12px}.mtc-launch .mtc-label{display:none}.mtc-launch{padding:9px}}
  `;
  document.head.appendChild(style);

  // ---- DOM ------------------------------------------------------------------
  const launch = document.createElement('button');
  launch.className = 'mtc-launch';
  launch.setAttribute('aria-label', 'Chat with the MONTRA Team');
  launch.innerHTML = `<span class="mtc-av" style="width:34px;height:34px">${AV}<span class="mtc-dot"></span></span><span class="mtc-label">Chat With The MONTRA Team</span>`;

  const panel = document.createElement('div');
  panel.className = 'mtc-panel';
  panel.innerHTML = `
    <div class="mtc-head">
      <span class="mtc-av" style="width:42px;height:42px">${AV}<span class="mtc-dot"></span></span>
      <div>
        <h4>MONTRA Team <span class="online"></span></h4>
        <div class="sub">We're here to help!</div>
      </div>
      <button class="mtc-x" aria-label="Close">&times;</button>
    </div>
    <div class="mtc-body" id="mtc-body"></div>
    <div class="mtc-foot">
      <div class="mtc-inrow">
        <input id="mtc-input" type="text" placeholder="Type your message..." autocomplete="off"/>
        <button class="mtc-send" id="mtc-send" aria-label="Send">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M3 11l18-8-8 18-2-7-8-3z"/></svg>
        </button>
      </div>
      <div class="mtc-reply">We typically reply in under 2 minutes.</div>
    </div>`;

  document.body.appendChild(launch);
  document.body.appendChild(panel);

  const body = panel.querySelector('#mtc-body');
  const input = panel.querySelector('#mtc-input');

  // ---- Conversation state ----------------------------------------------------
  const context = {};      // collected: goal, trainingLocation, city, startTiming, intent
  let awaitingCity = false;
  let started = false;

  const scroll = () => { body.scrollTop = body.scrollHeight; };

  function avatar(size) { return `<span class="mtc-av" style="width:${size}px;height:${size}px">${AV}</span>`; }

  function maya(html) {
    const row = document.createElement('div');
    row.className = 'mtc-row';
    row.innerHTML = `${avatar(30)}<div class="mtc-bubble maya">${html}</div>`;
    body.appendChild(row); scroll();
  }
  function user(text) {
    const row = document.createElement('div');
    row.className = 'mtc-row';
    row.innerHTML = `<div class="mtc-bubble user">${esc(text)}</div>`;
    body.appendChild(row); scroll();
  }
  // A standalone block (quick actions / option chips / forms) not in a bubble.
  function block(html) {
    const d = document.createElement('div');
    d.innerHTML = html;
    body.appendChild(d); scroll();
    return d;
  }
  function options(opts, onPick) {
    const wrap = block(`<div class="mtc-opts">${opts.map((o, i) => `<button class="mtc-chip" data-i="${i}">${esc(o.label)}</button>`).join('')}</div>`);
    wrap.querySelectorAll('.mtc-chip').forEach((b) => b.addEventListener('click', () => {
      const o = opts[Number(b.dataset.i)];
      wrap.remove();
      user(o.label);
      onPick(o);
    }, { once: true }));
  }

  // ---- Flows -----------------------------------------------------------------
  function openingActions() {
    const acts = [
      { ic: '🎯', t: 'Find My Coach', d: "We'll match you with the right coach", fn: startDiscovery },
      { ic: '📅', t: 'Book Consultation', d: 'Schedule your free consultation', fn: startDiscovery },
      { ic: '❓', t: 'How It Works', d: 'Learn about the process', fn: howItWorks },
      { ic: '💰', t: 'Pricing', d: 'View pricing & packages', fn: pricing },
      { ic: '🛡️', t: 'MONTRA Match Guarantee™', d: 'Your protection & priority', fn: guarantee },
      { ic: '👤', t: 'Talk To A Human', d: 'Connect with our team', fn: () => callbackForm() },
    ];
    const wrap = block(`<div class="mtc-qa">${acts.map((a, i) => `
      <button class="mtc-qa-card" data-i="${i}"><span class="ic">${a.ic}</span><span><span class="t">${a.t}</span><span class="d">${a.d}</span></span></button>`).join('')}</div>`);
    wrap.querySelectorAll('.mtc-qa-card').forEach((b) => b.addEventListener('click', () => acts[Number(b.dataset.i)].fn()));
  }

  function bookCTA(label) {
    const wrap = block(`
      <a class="mtc-cta" href="quiz.html">📅 ${label || 'Book My Free Consultation'}</a>
      <button class="mtc-cta ghost" id="mtc-cb">👤 Have the MONTRA Team call me</button>`);
    wrap.querySelector('#mtc-cb').addEventListener('click', () => callbackForm());
  }

  function startDiscovery() {
    context.intent = 'book_consultation';
    maya("Love it — let's find your perfect fit. A few quick questions. 💪");
    setTimeout(askGoal, 350);
  }
  function askGoal() {
    maya('First, what’s your <b>primary goal</b>?');
    options([
      { label: 'Build Muscle' }, { label: 'Lose Weight' }, { label: 'Flexibility & Wellness' },
      { label: 'Athletic Performance' }, { label: 'General Fitness' },
    ], (o) => { context.goal = o.label; askLocation(); });
  }
  function askLocation() {
    maya('Where would you like to <b>train</b>?');
    options([
      { label: 'Home' }, { label: 'Apartment Gym' }, { label: 'Office' }, { label: 'Outdoors' }, { label: 'Online' },
    ], (o) => { context.trainingLocation = o.label; askCity(); });
  }
  function askCity() {
    maya('Got it. What <b>city</b> are you located in? <span style="color:#9aa0a6">(type it below)</span>');
    awaitingCity = true;
    input.focus();
  }
  function askStart() {
    maya('Perfect. When would you like to <b>start</b>?');
    options([
      { label: 'As soon as possible' }, { label: 'This week' }, { label: 'This month' }, { label: 'Just exploring' },
    ], (o) => { context.startTiming = o.label; askMatchOrBrowse(); });
  }
  function askMatchOrBrowse() {
    maya('Last one — would you like us to <b>match you</b> with a coach, or <b>browse</b> available coaches?');
    options([
      { label: 'Match me with a coach', v: 'match' }, { label: 'Browse coaches', v: 'browse' },
    ], (o) => finishDiscovery(o.v));
  }
  function finishDiscovery(choice) {
    const city = context.city ? ` in ${esc(context.city)}` : '';
    if (choice === 'browse') {
      maya(`Great — you can browse our vetted coaches${city} any time. When you’re ready, the best next step is a free consultation so we can confirm the right fit for your ${esc(context.goal || 'goals').toLowerCase()}.`);
      block(`<a class="mtc-cta ghost" href="/">🔍 Browse Coaches</a>`);
    } else {
      maya(`Perfect — based on your goals${city}, MONTRA will match you with the right coach. The fastest way to lock it in is a free consultation. 🎯`);
    }
    bookCTA('Book My Free Consultation');
  }

  function howItWorks() {
    maya('Here’s how Elite Home Fitness works, simply:<br>1️⃣ Tell us your goals<br>2️⃣ We match you with a vetted coach<br>3️⃣ Train at home, on your schedule — backed by the MONTRA Match Guarantee™.');
    block(`<a class="mtc-cta ghost" href="how-it-works.html">❓ See the full process</a>`);
    setTimeout(() => { maya('Want me to get your free consultation booked?'); bookCTA(); }, 400);
  }
  function pricing() {
    maya('We keep pricing simple and transparent — coaches offer session packages and monthly programs, and every plan is protected by the MONTRA Match Guarantee™.');
    block(`<a class="mtc-cta ghost" href="pricing.html">💰 View pricing & packages</a>`);
    setTimeout(() => { maya('The best value starts with a free consultation — want me to set one up?'); bookCTA(); }, 400);
  }
  function guarantee() {
    maya(`🛡️ ${GUARANTEE}`);
    setTimeout(() => { maya('It’s risk-free to start — shall I book your free consultation?'); bookCTA(); }, 400);
  }

  // ---- Talk to a Human → callback form --------------------------------------
  function callbackForm() {
    maya('Of course — a member of our team would be happy to call you. 📞');
    const form = block(`
      <div class="mtc-form">
        <div class="fh">
          <div class="ph"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.6 10.8a15 15 0 006.6 6.6l2.2-2.2a1 1 0 011-.24 11 11 0 003.5.56 1 1 0 011 1V20a1 1 0 01-1 1A17 17 0 013 4a1 1 0 011-1h3.5a1 1 0 011 1 11 11 0 00.56 3.5 1 1 0 01-.24 1l-2.22 2.3z"/></svg></div>
          <h5>Need help from a real person?</h5>
          <p>A member of the MONTRA Team can call you.</p>
        </div>
        <div class="mtc-field"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12a5 5 0 100-10 5 5 0 000 10zm0 2c-4 0-8 2-8 5v1h16v-1c0-3-4-5-8-5z"/></svg><input id="cb-name" placeholder="First Name*"/></div>
        <div class="mtc-field"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M6.6 10.8a15 15 0 006.6 6.6l2.2-2.2a1 1 0 011-.24 11 11 0 003.5.56 1 1 0 011 1V20a1 1 0 01-1 1A17 17 0 013 4a1 1 0 011-1h3.5a1 1 0 011 1 11 11 0 00.56 3.5 1 1 0 01-.24 1l-2.22 2.3z"/></svg><input id="cb-phone" type="tel" placeholder="Phone Number*"/></div>
        <div class="mtc-field"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 4h16a1 1 0 011 1v14a1 1 0 01-1 1H4a1 1 0 01-1-1V5a1 1 0 011-1zm8 7L4.5 6.5v.5L12 12l7.5-5v-.5L12 11z"/></svg><input id="cb-email" type="email" placeholder="Email (Optional)"/></div>
        <div class="mtc-field"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 4h16v12H7l-3 3V4z"/></svg>
          <select id="cb-help">
            <option value="">How can we help?</option>
            <option>Choosing a coach</option>
            <option>Pricing question</option>
            <option>Booking a consultation</option>
            <option>Something else</option>
          </select>
        </div>
        <div class="mtc-err" id="cb-err" style="display:none"></div>
        <button class="mtc-cta" id="cb-submit">Request A Call</button>
        <div class="mtc-secure">🔒 Your information is secure and will never be shared.</div>
      </div>`);

    const submit = form.querySelector('#cb-submit');
    submit.addEventListener('click', async () => {
      const firstName = form.querySelector('#cb-name').value.trim();
      const phone = form.querySelector('#cb-phone').value.trim();
      const email = form.querySelector('#cb-email').value.trim();
      const help = form.querySelector('#cb-help').value;
      const err = form.querySelector('#cb-err');
      err.style.display = 'none';
      if (!firstName || !phone) { err.textContent = 'Please add your first name and phone number.'; err.style.display = 'block'; return; }
      submit.disabled = true; submit.textContent = 'Requesting…';
      try {
        const res = await fetch(`${BACKEND_URL}/api/leads/callback`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ firstName, phone, email, message: help, source: SOURCE, sourcePath: SOURCE_PATH, context }),
        });
        if (!res.ok) throw new Error('failed');
        form.remove();
        confirmation();
      } catch (_) {
        err.textContent = 'Something went wrong. Please try again.'; err.style.display = 'block';
        submit.disabled = false; submit.textContent = 'Request A Call';
      }
    });
  }

  function confirmation() {
    block(`
      <div class="mtc-conf">
        <div class="ck">✓</div>
        <h5>Request Received!</h5>
        <p>A member of the MONTRA Team will contact you within <span class="eta">10–15 minutes</span> during business hours.<br><br>For urgent requests, please call our main office.</p>
      </div>`);
  }

  // ---- Free-text handling (light concierge routing) --------------------------
  function handleTyped(text) {
    user(text);
    if (awaitingCity) {
      awaitingCity = false;
      context.city = text;
      setTimeout(askStart, 300);
      return;
    }
    const t = text.toLowerCase();
    if (/(human|call me|talk|agent|person|representative)/.test(t)) return void callbackForm();
    if (/(price|pricing|cost|how much|package)/.test(t)) return void pricing();
    if (/(guarantee|refund|risk)/.test(t)) return void guarantee();
    if (/(how|process|work)/.test(t)) return void howItWorks();
    if (/(book|consult|appointment|schedule)/.test(t)) return void startDiscovery();
    if (/(coach|match|trainer|find)/.test(t)) return void startDiscovery();
    maya("Happy to help with that! The best next step is a quick free consultation so we can match you with the right coach. Want me to set one up — or I can connect you with a real person?");
    bookCTA();
  }

  // ---- Boot ------------------------------------------------------------------
  function start() {
    if (started) return;
    started = true;
    maya('Hi, I’m <b>Maya</b>, part of the MONTRA Team. 👋');
    setTimeout(() => {
      maya('I can help you find the right coach, explain how Elite Home Fitness works, answer questions, or help you book your consultation.<br><br>What would you like to do?');
      block(`<div class="mtc-time">${new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</div>`);
      openingActions();
    }, 450);
  }

  function open() { panel.classList.add('open'); launch.classList.add('hide'); start(); setTimeout(() => input.focus(), 80); }
  function close() { panel.classList.remove('open'); launch.classList.remove('hide'); }

  launch.addEventListener('click', open);
  panel.querySelector('.mtc-x').addEventListener('click', close);
  panel.querySelector('#mtc-send').addEventListener('click', () => { const v = input.value.trim(); if (v) { input.value = ''; handleTyped(v); } });
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') { const v = input.value.trim(); if (v) { input.value = ''; handleTyped(v); } } });
})();
