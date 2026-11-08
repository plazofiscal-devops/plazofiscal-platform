<template>
  <div class="login-page">
    <spinner v-show="loggingIn" message="Ingresando..."></spinner>

    <section class="login-hero">
      <svg class="login-ring" viewBox="0 0 32 32" aria-hidden="true">
        <g fill="#f0f0f0" opacity="0.35">
          <circle cx="9" cy="9" r="1.6"/><circle cx="16" cy="9" r="1.6"/><circle cx="23" cy="9" r="1.6"/>
          <circle cx="9" cy="16" r="1.6"/><circle cx="16" cy="16" r="1.6"/>
          <circle cx="9" cy="23" r="1.6"/><circle cx="16" cy="23" r="1.6"/><circle cx="23" cy="23" r="1.6"/>
        </g>
        <circle cx="23" cy="16" r="2.6" fill="#f2c14e"/>
      </svg>
      <brand large></brand>
      <div class="login-message">
        <h1>Ningún vencimiento se pasa por alto.</h1>
        <p>Las obligaciones tributarias de los clientes de tu firma, ordenadas por fecha y con alertas antes de que venzan.</p>
      </div>
      <p class="login-footer">Para firmas contables en Colombia</p>
    </section>

    <section class="login-panel">
      <form class="login-form" v-on:submit.prevent="doLogin">
        <h2>Iniciar sesión</h2>
        <p class="login-hint">Ingresa con tu usuario de la firma.</p>

        <label class="login-label" for="username">Usuario</label>
        <input
          id="username"
          type="text"
          class="pf-input"
          autocomplete="username"
          v-model="credentials.username"
          required
          autofocus
        >

        <label class="login-label" for="password">Contraseña</label>
        <input
          id="password"
          type="password"
          class="pf-input"
          autocomplete="current-password"
          v-model="credentials.password"
          required
        >

        <div class="pf-error login-error">{{ errorMessage }}</div>
        <button type="submit" class="pf-button login-submit">Ingresar</button>
      </form>
    </section>
  </div>
</template>

<script>
import Spinner from '@/components/common/Spinner'
import Brand from '@/components/common/Brand'

export default {
  name: 'login',
  components: { Brand, Spinner },
  methods: {
    doLogin: function () {
      this.loggingIn = true
      this.errorMessage = ''

      const credentials = {
        username: this.credentials.username,
        password: this.credentials.password
      }

      this.$auth.login(credentials, 'todos').then(response => {
        this.loggingIn = false
        if (response.status === 401) {
          this.errorMessage = 'Usuario o contraseña incorrectos.'
        } else if (!response.ok) {
          this.errorMessage = 'No fue posible iniciar sesión. Intenta de nuevo en un momento.'
        }
      })
    }
  },
  data () {
    return {
      credentials: {
        username: '',
        password: ''
      },
      errorMessage: '',
      loggingIn: false
    }
  }
}
</script>

<style scoped>
.login-page {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr);
  min-height: 100vh;
}

.login-hero {
  background: radial-gradient(circle at 15% 85%, rgba(242, 193, 78, 0.08), transparent 55%), var(--pf-panel);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 3.5rem 4rem;
  position: relative;
}

.login-ring {
  height: 16rem;
  opacity: 0.35;
  position: absolute;
  right: 4rem;
  top: 50%;
  transform: translateY(-50%);
  width: 16rem;
}

.login-message {
  margin: auto 0;
  max-width: 30rem;
  position: relative;
}

.login-message h1 {
  font-size: 2.6rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
  margin: 0 0 1.2rem;
}

.login-message p {
  color: var(--pf-muted);
  font-size: 1.15rem;
  line-height: 1.6;
  margin: 0;
}

.login-footer {
  color: var(--pf-muted);
  font-size: 0.9rem;
  margin: 0;
  position: relative;
}

.login-panel {
  align-items: center;
  display: flex;
  justify-content: center;
  padding: 2rem;
}

.login-form {
  max-width: 360px;
  width: 100%;
}

.login-form h2 {
  font-size: 1.7rem;
  font-weight: 700;
  margin: 0;
}

.login-hint {
  color: var(--pf-muted);
  margin: 0.4rem 0 1.6rem;
}

.login-label {
  color: var(--pf-muted);
  display: block;
  font-size: 0.9rem;
  margin: 1rem 0 0.4rem;
}

.login-error {
  margin-top: 0.9rem;
}

.login-submit {
  margin-top: 0.4rem;
  width: 100%;
}

@media (max-width: 991px) {
  .login-page {
    grid-template-columns: 1fr;
  }

  .login-hero {
    padding: 2rem 1.5rem 2.5rem;
  }

  .login-ring {
    display: none;
  }

  .login-message {
    margin: 2.5rem 0 1.5rem;
  }

  .login-message h1 {
    font-size: 1.9rem;
  }
}
</style>
