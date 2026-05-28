const b64uToBuf = (s) =>
  Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

const bufToB64u = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

const csrfToken = () =>
  document.head.querySelector("meta[name=csrf-token]").getAttribute("content");

const PasskeySignIn = {
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

    const headers = {
      "Content-Type": "application/json",
      "x-csrf-token": csrfToken()
    };

    let opts;
    try {
      const res = await fetch("/passkey/sign-in/options", {
        method: "POST",
        credentials: "same-origin",
        headers,
        body: "{}"
      });
      opts = await res.json();
    } catch (err) {
      this.setStatus(`Could not start sign-in: ${err.message}`);
      return;
    }

    let credential;
    try {
      credential = await navigator.credentials.get({
        publicKey: {
          challenge: b64uToBuf(opts.challenge),
          rpId: opts.rpId,
          timeout: opts.timeout,
          userVerification: opts.userVerification
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
          authenticatorData: bufToB64u(credential.response.authenticatorData),
          clientDataJSON: bufToB64u(credential.response.clientDataJSON),
          signature: bufToB64u(credential.response.signature),
          userHandle: credential.response.userHandle
            ? bufToB64u(credential.response.userHandle)
            : null
        }
      }
    };

    try {
      const res = await fetch("/passkey/sign-in/finish", {
        method: "POST",
        credentials: "same-origin",
        headers,
        body: JSON.stringify(payload)
      });
      const result = await res.json();
      if (result.ok) {
        window.location.href = result.redirect || "/feed";
      } else {
        this.setStatus(`Sign-in failed: ${result.error}`);
      }
    } catch (err) {
      this.setStatus(`Server error: ${err.message}`);
    }
  }
};

export default PasskeySignIn;
