<template>
  <div class="raindrop-container">
    <div 
      class="raindrop" 
      v-for="i in count" 
      :key="i"
      :style="getStyle()"
    ></div>
  </div>
</template>

<script>
export default {
  name: 'Raindrop',
  props: {
    chance: {
      type: Number,
      default: 0
    }
  },
  computed: {
    count() {
      if (this.chance <= 0) return 0;
      if (this.chance >= 100) return 100; // Plethora of raindrops
      return Math.floor(this.chance);
    }
  },
  methods: {
    getStyle() {
      const left = Math.random() * 100;
      const top = Math.random() * 100;
      const animationDuration = (Math.random() * 0.5 + 0.5).toFixed(2);
      const animationDelay = (Math.random() * 2).toFixed(2);
      return {
        left: `${left}%`,
        top: `${top}%`,
        animation: `fall ${animationDuration}s linear ${animationDelay}s infinite`,
      };
    }
  }
};
</script>

<style scoped>
.raindrop-container {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  z-index: 0;
}

.raindrop {
  position: absolute;
  width: 1px;
  height: 50px;
  background: linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(138,187,218,0.5) 100%);
}

@keyframes fall {
  from {
    transform: translateY(-100px);
  }
  to {
    transform: translateY(100vh);
  }
}
</style> 