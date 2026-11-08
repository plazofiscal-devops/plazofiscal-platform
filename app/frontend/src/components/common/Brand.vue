<template>
  <div class="brand">
    <svg class="brand-mark" viewBox="0 0 32 32" aria-hidden="true">
      <rect x="3" y="6" width="26" height="23" rx="5" fill="#f2c14e"/>
      <rect x="9" y="2" width="3" height="8" rx="1.5" fill="#f2c14e"/>
      <rect x="20" y="2" width="3" height="8" rx="1.5" fill="#f2c14e"/>
      <path d="M10 19.5l4 4 8-9" fill="none" stroke="#1b1b1b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
    <span class="brand-name">PlazoFiscal</span>
  </div>
</template>

<script>
export default {
  name: 'brand'
}
</script>

<style scoped>
.brand {
  align-items: center;
  display: flex;
  gap: 0.6rem;
}

.brand-mark {
  height: 2rem;
  width: 2rem;
}

.brand-name {
  font-size: 1.6rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}
</style>
