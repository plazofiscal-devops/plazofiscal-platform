<template>
  <div class="brand" :class="{ 'brand-large': large }">
    <svg class="brand-mark" viewBox="0 0 32 32" aria-hidden="true">
      <g fill="#5a5a5a">
        <circle cx="9" cy="9" r="2.4"/><circle cx="16" cy="9" r="2.4"/><circle cx="23" cy="9" r="2.4"/>
        <circle cx="9" cy="16" r="2.4"/><circle cx="16" cy="16" r="2.4"/>
        <circle cx="9" cy="23" r="2.4"/><circle cx="16" cy="23" r="2.4"/><circle cx="23" cy="23" r="2.4"/>
      </g>
      <circle cx="23" cy="16" r="3.6" fill="#f2c14e"/>
    </svg>
    <span class="brand-name"><span class="brand-light">Plazo</span>Fiscal</span>
  </div>
</template>

<script>
export default {
  name: 'brand',
  props: {
    large: {
      type: Boolean,
      default: false
    }
  }
}
</script>

<style scoped>
.brand {
  align-items: center;
  display: flex;
  gap: 0.55rem;
}

.brand-mark {
  height: 1.9rem;
  width: 1.9rem;
}

.brand-name {
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: -0.03em;
}

.brand-light {
  font-weight: 300;
}

.brand-large .brand-mark {
  height: 2.6rem;
  width: 2.6rem;
}

.brand-large .brand-name {
  font-size: 2.1rem;
}
</style>
