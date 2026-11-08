<template>
  <div class="login-page">
    <spinner v-show="loggingIn" message="Ingresando..."></spinner>
    <form class="login-card" v-on:submit.prevent="doLogin">
      <brand></brand>
      <p class="login-intro">Las obligaciones tributarias de tus clientes, al día.</p>

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
  align-items: center;
  display: flex;
  justify-content: center;
  min-height: 100vh;
  padding: 1rem;
}

.login-card {
  background: var(--pf-panel);
  border-radius: 14px;
  max-width: 400px;
  padding: 2.5rem 2rem;
  width: 100%;
}

.login-intro {
  color: var(--pf-muted);
  margin: 0.8rem 0 1.8rem;
}

.login-label {
  color: var(--pf-muted);
  display: block;
  font-size: 0.9rem;
  margin: 0.9rem 0 0.4rem;
}

.login-error {
  margin-top: 0.9rem;
}

.login-submit {
  margin-top: 0.4rem;
  width: 100%;
}
</style>
