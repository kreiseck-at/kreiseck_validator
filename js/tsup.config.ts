import { defineConfig } from 'tsup';

export default defineConfig({
  entry: [
    'src/index.ts',
    'src/email/index.ts',
    'src/phone/index.ts',
    'src/url/index.ts',
    'src/iban/index.ts',
    'src/credit-card/index.ts',
    'src/imei/index.ts',
    'src/iccid/index.ts',
    'src/mac-address/index.ts',
    'src/license-plate/index.ts',
    'src/vin/index.ts',
    'src/postal-code/index.ts',
  ],
  format: ['esm', 'cjs'],
  dts: true,
  clean: true,
  treeshake: true,
});
