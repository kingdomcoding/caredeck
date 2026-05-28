const ShareCameraInput = {
  mounted() {
    this.el.addEventListener("change", () => {
      if (this.el.files.length === 0) return;

      const target = document.querySelector(
        `input[type=file][data-phx-upload-ref="${this.el.dataset.target}"]`
      );
      if (!target) return;

      const dt = new DataTransfer();
      Array.from(target.files || []).forEach((f) => dt.items.add(f));
      Array.from(this.el.files).forEach((f) => dt.items.add(f));
      target.files = dt.files;
      target.dispatchEvent(new Event("change", { bubbles: true }));

      this.el.value = "";
    });
  }
};

export default ShareCameraInput;
