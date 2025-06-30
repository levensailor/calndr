<template>
  <div class="lock-screen">
    <div class="lock-screen-container">
      <div class="clock">{{ currentTime }}</div>
      <div class="date-display">{{ currentDate }}</div>

      <div class="pin-entry">
        <p class="pin-prompt" v-if="!isLockedOut">{{ pinPromptText }}</p>
        <p class="pin-prompt lockout-message" v-else>{{ lockoutMessage }}</p>
        <div class="pin-dots" :class="{ 'shake': shaking }">
          <div
            class="dot"
            v-for="i in 5"
            :key="`dot-${i}`"
            :class="{ 'filled': pin.length >= i }"
          ></div>
        </div>
      </div>

      <div class="keypad">
        <div class="keypad-row" v-for="row in keypad" :key="row">
          <button
            class="keypad-button"
            v-for="key in row"
            :key="key"
            @click="onKeyPress(key)"
            :disabled="isLockedOut"
          >
            <span class="key-number">{{ key }}</span>
            <span class="key-letters">{{ keypadLetters[key] }}</span>
          </button>
        </div>
        <div class="keypad-row">
           <div class="keypad-button-placeholder"></div>
           <button class="keypad-button" @click="onKeyPress('0')" :disabled="isLockedOut">
             <span class="key-number">0</span>
           </button>
           <button class="keypad-button keypad-icon" @click="onBackspace" :disabled="isLockedOut">⌫</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
const MAX_ATTEMPTS = 3;
const ATTEMPT_WINDOW_MINUTES = 5;
const LOCKOUT_DURATIONS_MINUTES = {
  3: 1, // 1 minute after 3rd failure
  4: 5, // 5 minutes after 4th
  5: 15, // 15 minutes after 5th or more
};

export default {
  name: 'LockScreen',
  data() {
    return {
      pin: '',
      alphaPin: '',
      correctPin: '76936',
      correctAlphaPin: 'rowen',
      keypad: [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ],
      keypadLetters: {
        '1': '', '2': 'ABC', '3': 'DEF',
        '4': 'GHI', '5': 'JKL', '6': 'MNO',
        '7': 'PQRS', '8': 'TUV', '9': 'WXYZ',
      },
      currentTime: this.formatTime(),
      currentDate: this.formatDate(),
      timer: null,
      shaking: false,
      isLockedOut: false,
      lockoutMessage: '',
    };
  },
  computed: {
    pinPromptText() {
        return this.pin.length > 0 ? '' : 'Enter PIN';
    }
  },
  methods: {
    formatTime() {
        const now = new Date();
        return now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    },
    formatDate() {
        const now = new Date();
        return now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
    },
    handleKeyDown(event) {
        if (this.isLockedOut) return;

        if (event.key >= '0' && event.key <= '9') {
            this.onKeyPress(event.key);
        } else if (event.key.toLowerCase() >= 'a' && event.key.toLowerCase() <= 'z') {
            this.onAlphaKeyPress(event.key.toLowerCase());
        } else if (event.key === 'Backspace') {
            this.onBackspace();
        }
    },
    onKeyPress(key) {
      if (this.alphaPin.length > 0) {
        this.alphaPin = '';
        this.pin = '';
      }
      if (this.pin.length < 5) {
        this.pin += key;
      }
      if (this.pin.length === 5) {
        this.checkPin();
      }
    },
    onAlphaKeyPress(key) {
      if (this.pin.length > 0 && this.alphaPin.length === 0) {
        this.pin = '';
      }
      if (this.alphaPin.length < 5) {
        this.alphaPin += key;
        this.pin += '•';
      }
      if (this.alphaPin.length === 5) {
        this.checkAlphaPin();
      }
    },
    onBackspace() {
      if (this.alphaPin.length > 0) {
        this.alphaPin = this.alphaPin.slice(0, -1);
        this.pin = this.pin.slice(0, -1);
      } else if (this.pin.length > 0) {
        this.pin = this.pin.slice(0, -1);
      }
    },
    checkPin() {
      if (this.pin === this.correctPin) {
        this.unlockSuccess();
      } else {
        this.handleFailedAttempt();
      }
    },
    checkAlphaPin() {
      if (this.alphaPin === this.correctAlphaPin) {
        this.unlockSuccess();
      } else {
        this.handleFailedAttempt(true);
      }
    },
    unlockSuccess() {
      localStorage.removeItem('loginAttempts');
      localStorage.setItem('lastSuccessfulLogin', Date.now());
      this.$emit('unlocked');
    },
    handleFailedAttempt(isAlpha = false) {
        this.shaking = true;
        setTimeout(() => {
          this.shaking = false;
          this.pin = '';
          this.alphaPin = '';
        }, 800);

        const now = Date.now();
        const attempts = JSON.parse(localStorage.getItem('loginAttempts') || '[]');
        const recentAttempts = attempts.filter(ts => now - ts < ATTEMPT_WINDOW_MINUTES * 60 * 1000);
        
        recentAttempts.push(now);
        localStorage.setItem('loginAttempts', JSON.stringify(recentAttempts));

        if (recentAttempts.length >= MAX_ATTEMPTS) {
            const lockoutDurationMins = LOCKOUT_DURATIONS_MINUTES[recentAttempts.length] || 15;
            const lockoutEndTime = now + lockoutDurationMins * 60 * 1000;
            localStorage.setItem('lockoutEndTime', lockoutEndTime);
            this.initiateLockout();
        }
    },
    initiateLockout() {
        const lockoutEndTime = parseInt(localStorage.getItem('lockoutEndTime') || '0');
        if (Date.now() < lockoutEndTime) {
            this.isLockedOut = true;
            this.updateLockoutMessage();
            this.timer = setInterval(this.updateLockoutMessage, 1000);
        }
    },
    updateLockoutMessage() {
        const lockoutEndTime = parseInt(localStorage.getItem('lockoutEndTime') || '0');
        const remaining = Math.round((lockoutEndTime - Date.now()) / 1000);

        if (remaining <= 0) {
            this.isLockedOut = false;
            this.lockoutMessage = '';
            localStorage.removeItem('lockoutEndTime');
            localStorage.removeItem('loginAttempts');
            clearInterval(this.timer);
            this.timer = setInterval(() => {
                this.currentTime = this.formatTime();
                this.currentDate = this.formatDate();
            }, 1000);
        } else {
            const minutes = Math.floor(remaining / 60);
            const seconds = remaining % 60;
            this.lockoutMessage = `Try again in ${minutes > 0 ? minutes + 'm ' : ''}${seconds}s`;
        }
    }
  },
  mounted() {
    window.addEventListener('keydown', this.handleKeyDown);
    this.initiateLockout();

    if (!this.isLockedOut) {
        this.timer = setInterval(() => {
            this.currentTime = this.formatTime();
            this.currentDate = this.formatDate();
        }, 1000);
    }
  },
  beforeDestroy() {
    window.removeEventListener('keydown', this.handleKeyDown);
    clearInterval(this.timer);
  }
};
</script>

<style scoped>
.lock-screen {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background-image: url('https://lh3.googleusercontent.com/pw/AP1GczMTQ-sYayYpt-4CXZM3f9bDPmAKKBOoR2jUX6YeSyyRypA_bnbwqTdH9baRABmx828sXHTOUbU2-axEgSXY8O5pPSwCsqkANHGTK9BCCa7JbuufuHk_Rh0F8Exz7GcDfl3FrWWotEd0ZHqrI2B3nVO2=w1000-h1000-s-no-gm?authuser=0');
  background-size: cover;
  background-position: center;
  color: #333; /* Darker text for light background */
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
  z-index: 9999;
}

.lock-screen::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(255, 255, 255, 0.3);
    backdrop-filter: blur(20px);
    z-index: -1;
}

.lock-screen-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-around;
    height: 100%;
    padding-bottom: 20px;
}

.clock {
    font-size: 5rem;
    font-weight: 200;
    margin-top: 10vh;
}

.date-display {
    font-size: 1.2rem;
    font-weight: 400;
}

.pin-entry {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 15px;
    margin-top: 5vh;
}

.pin-prompt {
    font-size: 1rem;
    font-weight: 400;
    min-height: 1.2em; /* Reserve space */
}

.lockout-message {
    color: #ff3b30;
}

.pin-dots {
  display: flex;
  gap: 20px;
}

.dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 1px solid #333; /* Darker border */
  background-color: transparent;
  transition: background-color 0.2s;
}

.dot.filled {
  background-color: #333; /* Darker fill */
}

.keypad {
    margin-top: auto;
    margin-bottom: 5vh;
}

.keypad-row {
  display: flex;
  justify-content: center;
  gap: 20px;
  margin-bottom: 15px;
}

.keypad-button {
  width: 70px;
  height: 70px;
  border-radius: 50%;
  border: none;
  background-color: rgba(255, 255, 255, 0.4); /* Light background for keys */
  color: #333; /* Darker text */
  font-size: 2rem;
  font-weight: 300; /* Slightly bolder for readability */
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s;
}

.keypad-button:disabled {
    background-color: rgba(200, 200, 200, 0.2);
    color: #999;
    cursor: not-allowed;
}

.key-number {
    line-height: 1;
}

.key-letters {
    font-size: 0.6rem;
    letter-spacing: 0.1em;
    font-weight: 500;
    margin-top: 2px;
}

.keypad-button:active {
  background-color: rgba(255, 255, 255, 0.6);
}

.keypad-button.keypad-icon {
    font-size: 1.5rem;
}
.keypad-button-placeholder {
    width: 70px;
    height: 70px;
}

.shake {
  animation: shake 0.82s cubic-bezier(.36,.07,.19,.97) both;
  transform: translate3d(0, 0, 0);
}

@keyframes shake {
  10%, 90% {
    transform: translate3d(-1px, 0, 0);
  }
  20%, 80% {
    transform: translate3d(2px, 0, 0);
  }
  30%, 50%, 70% {
    transform: translate3d(-4px, 0, 0);
  }
  40%, 60% {
    transform: translate3d(4px, 0, 0);
  }
}
</style> 