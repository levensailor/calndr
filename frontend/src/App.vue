<template>
  <div id="app">
    <LockScreen v-if="isLocked" @unlocked="onUnlocked" />
    <Calendar v-else />
  </div>
</template>

<script>
import Calendar from './components/Calendar.vue';
import LockScreen from './components/LockScreen.vue';

export default {
  name: 'App',
  components: {
    Calendar,
    LockScreen,
  },
  data() {
    return {
      isLocked: true,
    };
  },
  methods: {
    onUnlocked() {
      this.isLocked = false;
    },
  },
  created() {
    const lastLogin = parseInt(localStorage.getItem('lastSuccessfulLogin') || '0');
    const fiveMinutes = 5 * 60 * 1000;
    if (Date.now() - lastLogin < fiveMinutes) {
      this.isLocked = false;
    }
  },
};
</script>

<style>
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
}
#app {
  font-family: 'Courier New', Courier, monospace;
}
</style> 