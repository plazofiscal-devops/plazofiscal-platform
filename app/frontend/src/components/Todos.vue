<template>
  <div class="layout">
    <spinner v-show="isProcessing" message="Procesando..."></spinner>

    <aside class="sidebar">
      <brand></brand>
      <div class="sidebar-user">Sesión de <strong>{{ username }}</strong></div>
      <button type="button" class="pf-button pf-button-quiet sidebar-logout" @click="logout">Cerrar sesión</button>
    </aside>

    <main class="main">
      <header class="heading">
        <div class="heading-date">
          <span>{{ todayMonth }}</span>
          <strong>{{ todayDay }}</strong>
        </div>
        <div>
          <h1 class="heading-greeting">{{ greeting }}.</h1>
          <p class="heading-question">¿Qué obligaciones vencen pronto?</p>
        </div>
      </header>

      <form class="new-obligation" v-on:submit.prevent="addObligation">
        <input class="pf-input" type="text" maxlength="120" placeholder="Cliente" aria-label="Cliente" v-model="draft.client">
        <select class="pf-input" aria-label="Impuesto" v-model="draft.tax">
          <option value="" disabled>Impuesto</option>
          <option v-for="tax in taxes" :key="tax.code" :value="tax.code">{{ tax.label }}</option>
        </select>
        <input class="pf-input" type="date" aria-label="Fecha de vencimiento" v-model="draft.dueDate">
        <input class="pf-input new-note" type="text" maxlength="500" placeholder="Nota opcional" aria-label="Nota" v-model="draft.note">
        <button type="submit" class="pf-button">Agregar obligación</button>
      </form>
      <div class="pf-error">{{ errorMessage }}</div>

      <ul class="obligations">
        <obligation-card
          v-for="obligation in obligations"
          :key="obligation.id"
          :obligation="obligation"
          @present="present(obligation)"
        ></obligation-card>
      </ul>
      <p v-if="!isProcessing && !obligations.length" class="empty">No hay obligaciones pendientes.</p>
    </main>
  </div>
</template>

<script>
import Brand from '@/components/common/Brand'
import ObligationCard from '@/components/ObligationCard'
import Spinner from '@/components/common/Spinner'
import { MONTHS, TAXES, today } from '@/obligations'

function emptyDraft () {
  return { client: '', tax: '', dueDate: '', note: '' }
}

export default {
  name: 'todos',
  components: { Brand, ObligationCard, Spinner },
  data () {
    return {
      isProcessing: false,
      errorMessage: '',
      tasks: [],
      draft: emptyDraft(),
      taxes: TAXES
    }
  },
  created () {
    this.loadTasks()
  },
  computed: {
    obligations () {
      return this.tasks
    },
    username () {
      return this.$store.state.user.name
    },
    todayMonth () {
      return MONTHS[today().getMonth()]
    },
    todayDay () {
      return today().getDate()
    },
    greeting () {
      const hour = new Date().getHours()
      if (hour < 12) {
        return 'Buenos días'
      }
      return hour < 19 ? 'Buenas tardes' : 'Buenas noches'
    }
  },
  methods: {
    loadTasks () {
      this.isProcessing = true
      this.$http.get('/todos').then(response => {
        this.tasks = response.body
        this.isProcessing = false
      }, () => {
        this.isProcessing = false
        this.errorMessage = 'No fue posible cargar las obligaciones. Intenta de nuevo en un momento.'
      })
    },

    addObligation () {
      if (!this.draft.client.trim() || !this.draft.tax || !this.draft.dueDate) {
        this.errorMessage = 'Completa el cliente, el impuesto y la fecha de vencimiento.'
        return
      }
      this.isProcessing = true
      this.errorMessage = ''
      this.$http.post('/todos', this.draft).then(() => {
        this.draft = emptyDraft()
        this.loadTasks()
      }, error => {
        this.isProcessing = false
        this.errorMessage = error.status === 400
          ? 'Revisa los datos de la obligación.'
          : 'No fue posible guardar la obligación. Intenta de nuevo en un momento.'
      })
    },

    present (obligation) {
      this.isProcessing = true
      this.errorMessage = ''
      this.$http.delete('/todos/' + obligation.id).then(() => {
        this.tasks = this.tasks.filter(item => item.id !== obligation.id)
        this.isProcessing = false
      }, () => {
        this.isProcessing = false
        this.errorMessage = 'No fue posible marcar la obligación como presentada.'
      })
    },

    logout () {
      this.$auth.logout()
    }
  }
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr) 340px;
  min-height: 100vh;
}

.sidebar {
  background: var(--pf-panel);
  display: flex;
  flex-direction: column;
  padding: 2rem 1.5rem;
}

.sidebar-user {
  color: var(--pf-muted);
  margin-top: auto;
  padding-top: 2rem;
}

.sidebar-logout {
  margin-top: 0.8rem;
}

.main {
  padding: 3rem 3rem 2rem;
}

.heading {
  align-items: center;
  display: flex;
  gap: 1.8rem;
  margin-bottom: 2.2rem;
}

.heading-date {
  display: flex;
  flex-direction: column;
  font-size: 1.6rem;
  line-height: 1.1;
  text-align: center;
  text-transform: capitalize;
}

.heading-date strong {
  font-size: 2rem;
}

.heading-greeting {
  font-size: 2.6rem;
  font-weight: 700;
  margin: 0;
}

.heading-question {
  color: var(--pf-muted);
  font-size: 1.6rem;
  font-weight: 600;
  margin: 0;
}

.new-obligation {
  background: var(--pf-card);
  border-radius: 12px;
  display: grid;
  gap: 0.7rem;
  grid-template-columns: 2fr 1.5fr 1.3fr;
  padding: 1rem;
}

.new-obligation .pf-input {
  background: var(--pf-panel);
}

.new-note {
  grid-column: span 2;
}

.obligations {
  margin: 0.5rem 0 0;
  padding: 0;
}

.empty {
  color: var(--pf-muted);
  margin-top: 1rem;
}

@media (max-width: 991px) {
  .layout {
    grid-template-columns: 1fr;
  }

  .sidebar-user {
    margin-top: 1rem;
    padding-top: 0;
  }

  .main {
    padding: 2rem 1rem;
  }

  .new-obligation {
    grid-template-columns: 1fr;
  }

  .new-note {
    grid-column: auto;
  }
}
</style>
