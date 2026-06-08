import { initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider, signInWithPopup } from "firebase/auth";
import "./style.css";

const appRoot = document.querySelector("#app");
const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://localhost:8080";

function render(message, token = "") {
  appRoot.innerHTML = `
    <main class="page">
      <h1>MONTRA Web Starter</h1>
      <p class="small">Backend: <code>${backendUrl}</code></p>

      <section class="card">
        <h2>1) Load Firebase Client Config</h2>
        <button id="load-config">Load Config</button>
        <pre id="config-output" class="small"></pre>
      </section>

      <section class="card">
        <h2>2) Sign In With Google</h2>
        <div class="row">
          <button id="google-login" ${message ? "" : "disabled"}>Sign in</button>
          <button id="call-backend" ${token ? "" : "disabled"}>Call /api/me</button>
        </div>
        <p id="auth-output" class="small">${message || "Load config first."}</p>
        <pre id="me-output" class="small"></pre>
      </section>
    </main>
  `;

  bindActions();
}

let firebaseApp = null;
let auth = null;
let idToken = "";

async function setupFirebase() {
  const res = await fetch(`${backendUrl}/api/firebase/client-config`);
  const config = await res.json();

  const output = document.querySelector("#config-output");
  output.textContent = JSON.stringify(config, null, 2);

  if (!config.apiKey || !config.authDomain || !config.appId || !config.projectId) {
    render("Config loaded, but Firebase client env vars are incomplete.");
    return;
  }

  firebaseApp = initializeApp(config);
  auth = getAuth(firebaseApp);
  render("Firebase initialized. You can sign in now.");
}

async function signInGoogle() {
  if (!auth) return;
  const provider = new GoogleAuthProvider();
  const result = await signInWithPopup(auth, provider);
  idToken = await result.user.getIdToken();
  render(`Signed in as ${result.user.email || result.user.uid}`, idToken);
}

async function callBackend() {
  if (!idToken) return;
  const res = await fetch(`${backendUrl}/api/me`, {
    headers: {
      Authorization: `Bearer ${idToken}`,
    },
  });
  const body = await res.json();
  const out = document.querySelector("#me-output");
  out.textContent = JSON.stringify(body, null, 2);
}

function bindActions() {
  document.querySelector("#load-config")?.addEventListener("click", () => {
    setupFirebase().catch((err) => {
      render(`Config error: ${err.message}`);
    });
  });

  document.querySelector("#google-login")?.addEventListener("click", () => {
    signInGoogle().catch((err) => {
      render(`Sign-in error: ${err.message}`);
    });
  });

  document.querySelector("#call-backend")?.addEventListener("click", () => {
    callBackend().catch((err) => {
      const out = document.querySelector("#me-output");
      if (out) out.textContent = `API error: ${err.message}`;
    });
  });
}

render("");
