const b64uToBuf = (s) =>
  Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

const bufToB64u = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

const csrfToken = () =>
  document.head.querySelector("meta[name=csrf-token]").getAttribute("content");

const PasskeyRegister = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      this.run();
    });
  },

  setStatus(msg) {
    if (this.el.dataset.statusTarget) {
      const target = document.querySelector(this.el.dataset.statusTarget);
      if (target) target.textContent = msg;
    }
  },

  async run() {
    if (!window.PublicKeyCredential) {
      this.setStatus("This browser does not support passkeys.");
      return;
    }

    const nickname = (this.el.dataset.nickname || "This device").trim();
    const headers = {
      "Content-Type": "application/json",
      "x-csrf-token": csrfToken()
    };

    let opts;
    try {
      const res = await fetch("/passkey/register/options", {
        method: "POST",
        credentials: "same-origin",
        headers,
        body: "{}"
      });
      opts = await res.json();
      if (opts.error) throw new Error(opts.error);
    } catch (err) {
      this.setStatus(`Could not start registration: ${err.message}`);
      return;
    }

    let credential;
    try {
      credential = await navigator.credentials.create({
        publicKey: {
          ...opts,
          challenge: b64uToBuf(opts.challenge),
          user: { ...opts.user, id: b64uToBuf(opts.user.id) },
          excludeCredentials: (opts.excludeCredentials || []).map((c) => ({
            ...c,
            id: b64uToBuf(c.id)
          }))
        }
      });
    } catch (err) {
      this.setStatus(`Cancelled: ${err.message}`);
      return;
    }

    const payload = {
      credential: {
        id: credential.id,
        rawId: bufToB64u(credential.rawId),
        type: credential.type,
        response: {
          attestationObject: bufToB64u(credential.response.attestationObject),
          clientDataJSON: bufToB64u(credential.response.clientDataJSON),
          transports:
            typeof credential.response.getTransports === "function"
              ? credential.response.getTransports()
              : []
        }
      },
      nickname
    };

    try {
      const res = await fetch("/passkey/register/finish", {
        method: "POST",
        credentials: "same-origin",
        headers,
        body: JSON.stringify(payload)
      });
      const result = await res.json();
      if (result.ok) {
        this.setStatus("Passkey saved. You can sign in with Face ID / Touch ID next time.");
        if (typeof this.pushEvent === "function") {
          this.pushEvent("passkey_registered", {});
        }
      } else {
        this.setStatus(`Registration failed: ${result.error}`);
      }
    } catch (err) {
      this.setStatus(`Server error: ${err.message}`);
    }
  }
};

export default PasskeyRegister;
