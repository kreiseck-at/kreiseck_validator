import { defineConfig } from 'tsup';

export default defineConfig({
  entry: [
    'src/index.ts',
    'src/email/index.ts',
    'src/phone/index.ts',
    'src/url/index.ts',
    'src/iban/index.ts',
    'src/credit-card/index.ts',
  ],
  format: ['esm', 'cjs'],
  dts: true,
  clean: true,
  treeshake: true,
});
