const MAX_MS = 60_000;

const pad2 = (n) => String(n).padStart(2, "0");
const fmtTimer = (ms) => {
  const s = Math.floor(ms / 1000);
  return `${Math.floor(s / 60)}:${pad2(s % 60)}`;
};

const AudioRecorder = {
  mounted() {
    this.recorder = null;
    this.chunks = [];
    this.startedAt = null;
    this.timerInterval = null;
    this.stream = null;

    this.toggle = this.el.querySelector("[data-role=record-toggle]");
    this.preview = this.el.querySelector("[data-role=preview]");
    this.status = this.el.querySelector("[data-role=status]");
    this.discard = this.el.querySelector("[data-role=discard]");
    this.timer = this.el.querySelector("[data-role=timer]");

    this.toggle.addEventListener("click", () => this.handleToggleClick());
    this.discard.addEventListener("click", () => this.handleDiscardClick());
  },

  destroyed() {
    this.stopTracks();
    if (this.recorder && this.recorder.state === "recording") {
      try { this.recorder.stop(); } catch (_e) { /* noop */ }
    }
    if (this.timerInterval) clearInterval(this.timerInterval);
  },

  setStatus(msg) {
    this.status.textContent = msg || "";
  },

  setTimerLabel(ms) {
    this.timer.textContent = fmtTimer(ms);
  },

  stopTracks() {
    if (this.stream) {
      this.stream.getTracks().forEach((t) => t.stop());
      this.stream = null;
    }
  },

  pickMime() {
    if (typeof MediaRecorder === "undefined") return null;
    const candidates = ["audio/webm;codecs=opus", "audio/webm", "audio/mp4"];
    return candidates.find((m) => MediaRecorder.isTypeSupported(m)) || "";
  },

  async handleToggleClick() {
    if (this.recorder && this.recorder.state === "recording") {
      this.recorder.stop();
      return;
    }

    const mime = this.pickMime();
    if (mime === null) {
      this.setStatus("This browser does not support audio recording.");
      return;
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (err) {
      this.setStatus(`Microphone unavailable: ${err.message}`);
      return;
    }

    try {
      this.recorder = new MediaRecorder(this.stream, mime ? { mimeType: mime } : undefined);
    } catch (err) {
      this.stopTracks();
      this.setStatus(`Recorder error: ${err.message}`);
      return;
    }

    this.chunks = [];
    this.recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) this.chunks.push(e.data);
    };
    this.recorder.onstop = () => this.handleStop();
    this.startedAt = Date.now();
    this.recorderMime = this.recorder.mimeType || mime || "audio/webm";

    this.timerInterval = setInterval(() => {
      const elapsed = Date.now() - this.startedAt;
      this.setTimerLabel(elapsed);
      if (elapsed >= MAX_MS && this.recorder.state === "recording") {
        this.recorder.stop();
      }
    }, 250);

    this.recorder.start();
    this.toggle.textContent = "Stop recording";
    this.setStatus("Recording…");
  },

  handleDiscardClick() {
    this.preview.classList.add("hidden");
    this.preview.removeAttribute("src");
    this.discard.classList.add("hidden");
    this.setTimerLabel(0);
    this.setStatus("");
    this.chunks = [];
    this.pushEventTo("#audio-recorder", "discard_audio", {});
  },

  async handleStop() {
    clearInterval(this.timerInterval);
    this.timerInterval = null;
    this.stopTracks();
    this.toggle.textContent = "Record voice note";

    const mime = this.recorderMime || "audio/webm";
    const blob = new Blob(this.chunks, { type: mime });
    if (blob.size === 0) {
      this.setStatus("Nothing recorded.");
      return;
    }

    const url = URL.createObjectURL(blob);
    this.preview.src = url;
    this.preview.classList.remove("hidden");
    this.discard.classList.remove("hidden");
    this.setStatus("Uploading…");

    const durationSec = Math.max(1, Math.round((Date.now() - this.startedAt) / 1000));
    const ext = mime.startsWith("audio/webm") ? "webm" : "m4a";
    const filename = `voice-${Date.now()}.${ext}`;

    try {
      const presigned = await this.requestPresignedUrl(filename);
      if (!presigned) throw new Error("no presigned url");

      const putRes = await fetch(presigned.upload_url, {
        method: "PUT",
        headers: { "Content-Type": mime },
        body: blob
      });
      if (!putRes.ok) throw new Error(`PUT failed: ${putRes.status}`);

      this.pushEventTo("#audio-recorder", "audio_uploaded", {
        s3_key: presigned.s3_key,
        mime_type: mime,
        bytes: blob.size,
        duration_sec: durationSec
      });
      this.setStatus(`Voice note attached (${durationSec}s).`);
    } catch (err) {
      this.setStatus(`Upload failed: ${err.message}`);
    }
  },

  requestPresignedUrl(filename) {
    return new Promise((resolve) => {
      this.pushEventTo("#audio-recorder", "request_audio_url", { filename }, (reply) => {
        resolve(reply && reply.presigned ? reply.presigned : null);
      });
    });
  }
};

export default AudioRecorder;
