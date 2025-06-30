<template>
  <div class="weather-fx-container">
    <div class="sun" :style="{ opacity: sunOpacity }"></div>
    <div
      v-for="cloud in clouds"
      :key="cloud.id"
      class="cloud"
      :style="cloud.style"
    >
      <div class="cloud-puff"></div>
      <div class="cloud-puff"></div>
      <div class="cloud-puff"></div>
      <div class="cloud-puff"></div>
    </div>
    <Raindrop v-if="precipitation > 20" :chance="precipitation" />
  </div>
</template>

<script>
import Raindrop from './Raindrop.vue';

export default {
  name: 'WeatherFX',
  components: {
    Raindrop,
  },
  props: {
    cloudCover: { // % value from 0-100
      type: Number,
      required: true,
    },
    precipitation: { // % value from 0-100
      type: Number,
      required: true,
    }
  },
  computed: {
    sunOpacity() {
      // Sun is less visible with more clouds and disappears above 65% cloud cover.
      // This threshold is chosen to show the sun on roughly 2/3 of days in a typical month.
      if (this.cloudCover > 65) {
        return 0;
      }
      return 1 - (this.cloudCover / 100);
    },
    clouds() {
      const cloudCount = Math.floor(this.cloudCover / 10); // Max 10 clouds
      const result = [];
      for (let i = 0; i < cloudCount; i++) {
        result.push({
          id: i,
          style: {
            top: `${5 + Math.random() * 50}%`,
            left: `${-20 + Math.random() * 100}%`,
            transform: `scale(${0.5 + Math.random() * 0.8})`,
            animation: `drift ${15 + Math.random() * 20}s linear infinite ${Math.random() * -35}s`,
          },
        });
      }
      return result;
    }
  },
};
</script>

<style scoped>
.weather-fx-container {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  z-index: 0;
}

.sun {
  position: absolute;
  top: 5%;
  left: 10%;
  width: 30px;
  height: 30px;
  background-color: #FFD700; /* Gold */
  border-radius: 50%;
  box-shadow: 0 0 20px 10px #FFD700;
  transition: opacity 1s ease-in-out;
}

.cloud {
  position: absolute;
  width: 50px;
  height: 15px;
  opacity: 0.8;
  filter: drop-shadow(0 2px 2px rgba(0,0,0,0.1));
}

.cloud-puff {
    position: absolute;
    border-radius: 50%;
    background-color: #f2f9fe;
    box-shadow: inset -2px -3px 0 0 #eaf3fa;
}
.cloud-puff:first-child { width: 25px; height: 25px; top: -15px; left: 10px; }
.cloud-puff:nth-child(2) { width: 20px; height: 20px; top: -10px; left: 0; }
.cloud-puff:nth-child(3) { width: 20px; height: 20px; top: -10px; right: 5px; }
.cloud-puff:nth-child(4) { width: 15px; height: 15px; top: 0; left: 15px; }

@keyframes drift {
  from {
    transform: translateX(-100px) scale(var(--scale));
  }
  to {
    transform: translateX(200px) scale(var(--scale));
  }
}
</style> 