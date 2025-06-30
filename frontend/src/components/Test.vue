<template>
  <div class="test">
    <h1>Test Component</h1>
    <p>Current time: {{ currentTime }}</p>
    <button @click="updateTime">Update Time</button>
  </div>
</template>

<script>
export default {
  name: 'Test',
  data() {
    return {
      currentTime: new Date().toLocaleString()
    };
  },
  methods: {
    updateTime() {
      this.currentTime = new Date().toLocaleString();
    }
  }
};
</script>

<style scoped>
.test {
  padding: 20px;
  text-align: center;
}
</style> 