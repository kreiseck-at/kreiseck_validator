import { describe, it, expect } from 'vitest';
import { prepare, groupEvery, groupWidths } from '../src/common/partial';
import type { FieldDescriptor } from '../src/common/field';

const vin: FieldDescriptor = {
  keyboard: 'text',
  autofill: null,
  capitalization: 'characters',
  maxLength: 17,
  example: null,
  allowedChars: '0-9A-HJ-NPR-Z',
};

describe('groupEvery', () => {
  it('leaves short input untouched', () => {
    expect(groupEvery('AT6', 4, ' ')).toBe('AT6');
    expect(groupEvery('AT61', 4, ' ')).toBe('AT61');
  });

  it('inserts separators without a trailing one', () => {
    expect(groupEvery('AT611', 4, ' ')).toBe('AT61 1');
    expect(groupEvery('AABBCC', 2, ':')).toBe('AA:BB:CC');
  });

  it('handles empty input', () => {
    expect(groupEvery('', 4, ' ')).toBe('');
  });
});

describe('groupWidths', () => {
  it('applies widths in order', () => {
    expect(groupWidths('378282246310005', [4, 6, 5], ' ')).toBe('3782 822463 10005');
    expect(groupWidths('37828', [4, 6, 5], ' ')).toBe('3782 8');
  });

  it('appends characters beyond the last width', () => {
    expect(groupWidths('3782822463100051', [4, 6, 5], ' ')).toBe('3782 822463 100051');
  });

  it('handles empty input', () => {
    expect(groupWidths('', [4, 6, 5], ' ')).toBe('');
  });
});

describe('prepare', () => {
  it('upper-cases before filtering', () => {
    expect(prepare('1hgcm8', vin)).toBe('1HGCM8');
  });

  it('drops characters outside allowedChars', () => {
    expect(prepare('1HGC-M8', vin)).toBe('1HGCM8');
    expect(prepare('1HGCIOQ', vin)).toBe('1HGC');
  });

  it('removes separators when asked', () => {
    const iban: FieldDescriptor = { ...vin, allowedChars: '0-9A-Z ' };
    expect(prepare('AT61 1904', iban, { separators: ' ' })).toBe('AT611904');
  });

  it('truncates to maxSignificant', () => {
    expect(prepare('1HGCM82633A004352XYZ', vin, { maxSignificant: 17 })).toBe('1HGCM82633A004352');
  });

  it('leaves case alone when capitalization is none', () => {
    const host: FieldDescriptor = { ...vin, capitalization: 'none', allowedChars: null };
    expect(prepare('Example.COM', host)).toBe('Example.COM');
  });
});
