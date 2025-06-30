import { createApp } from 'vue'
import App from './App.vue'
import './assets/main.css'
import axios from 'axios'

console.log("main.js: Starting Vue application");

// Set the base URL for your backend API
axios.defaults.baseURL = 'https://calndr.club'

// Remove the ngrok header since we're using your production domain
// axios.defaults.headers.common['ngrok-skip-browser-warning'] = 'true'

const app = createApp(App)

// Make axios available globally
app.config.globalProperties.$http = axios

app.mount('#app')

console.log("main.js: Vue application mounted"); 