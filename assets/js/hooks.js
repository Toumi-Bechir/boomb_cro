const InfiniteScroll = {
    mounted() {
      this.observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const page = this.el.dataset.page || 0;
            this.pushEvent("load-more", { page: parseInt(page) + 1 });
            this.el.dataset.page = parseInt(page) + 1;
          }
        });
      }, { threshold: 0.1 });
  
      const sentinel = document.createElement("div");
      sentinel.id = "sentinel";
      this.el.appendChild(sentinel);
      this.observer.observe(sentinel);
    },
    destroyed() {
      this.observer.disconnect();
    }
  };
  
  export default { InfiniteScroll };