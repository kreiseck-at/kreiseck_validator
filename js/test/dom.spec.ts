// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { fieldAttrs, filterValue, bindInput } from '../src/dom/index';
import { Iban } from '../src/iban/index';
import { Email } from '../src/email/index';
import { VatId } from '../src/vat-id/index';

const ibanAt = Iban.fieldDescriptor({ country: 'AT' });
const ibanOpts = { country: 'AT' };

function boundInput(onState?: (s: unknown) => void) {
  const el = document.createElement('input');
  document.body.append(el);
  const unbind = bindInput(el, {
    descriptor: ibanAt,
    formatPartial: (v) => Iban.formatPartial(v, ibanOpts),
    validate: (v) => Iban.validate(v, ibanOpts),
    onState: onState as never,
  });
  return { el, unbind };
}

describe('fieldAttrs', () => {
  it('maps an IBAN descriptor', () => {
    const a = fieldAttrs(ibanAt);
    expect(a.inputMode).toBe('text');
    expect(a.autoCapitalize).toBe('characters');
    expect(a.autoComplete).toBeUndefined();
    expect(a.maxLength).toBe(24);
    expect(a.placeholder).toBe('AT61 1904 3002 3457 3201');
  });

  it('maps a digits keyboard to inputmode numeric', () => {
    expect(fieldAttrs(VatId.fieldDescriptor({ country: 'AT' })).maxLength).toBe(11);
    expect(fieldAttrs(Email.fieldDescriptor()).inputMode).toBe('email');
  });

  it('maps an autofill hint to autoComplete', () => {
    expect(fieldAttrs(Email.fieldDescriptor()).autoComplete).toBe('email');
  });

  it('omits maxLength when the type has no useful bound', () => {
    expect(fieldAttrs(Email.fieldDescriptor()).maxLength).toBeUndefined();
  });

  it('omits the placeholder on request', () => {
    expect(fieldAttrs(Email.fieldDescriptor(), { placeholder: false }).placeholder)
      .toBeUndefined();
  });
});

describe('filterValue', () => {
  it('upper-cases, drops rejected characters and keeps separators', () => {
    expect(filterValue('at61 1904*3002', ibanAt)).toBe('AT61 19043002');
  });

  it('truncates to the descriptor maxLength', () => {
    expect(filterValue('A'.repeat(40), ibanAt)).toHaveLength(24);
  });

  it('leaves a descriptor without allowedChars alone', () => {
    expect(filterValue('User@Example.com', Email.fieldDescriptor()))
      .toBe('User@Example.com');
  });
});

describe('bindInput', () => {
  it('applies the descriptor to the element', () => {
    const { el } = boundInput();
    expect(el.inputMode).toBe('text');
    expect(el.getAttribute('autocapitalize')).toBe('characters');
    expect(el.maxLength).toBe(24);
    expect(el.placeholder).toBe('AT61 1904 3002 3457 3201');
  });

  it('does not overwrite a placeholder the caller set', () => {
    const el = document.createElement('input');
    el.placeholder = 'Your IBAN';
    bindInput(el, {
      descriptor: ibanAt,
      formatPartial: (v) => Iban.formatPartial(v, ibanOpts),
      validate: (v) => Iban.validate(v, ibanOpts),
    });
    expect(el.placeholder).toBe('Your IBAN');
  });

  it('formats as the user types', () => {
    const { el } = boundInput();
    el.value = 'AT611904300234573201';
    el.setSelectionRange(20, 20);
    el.dispatchEvent(new Event('input'));
    expect(el.value).toBe('AT61 1904 3002 3457 3201');
  });

  it('keeps the caret at the end when typing at the end', () => {
    const { el } = boundInput();
    el.value = 'AT611904';
    el.setSelectionRange(8, 8);
    el.dispatchEvent(new Event('input'));
    expect(el.value).toBe('AT61 1904');
    // Eight significant characters typed, so the caret sits after the eighth.
    expect(el.selectionStart).toBe(9);
  });

  it('restores the caret by significant offset when editing mid-value', () => {
    const { el } = boundInput();
    // The user had "AT61 1904 3002" and typed a 9 after "AT61 19".
    el.value = 'AT61 199 043002';
    el.setSelectionRange(8, 8); // just after the inserted 9
    el.dispatchEvent(new Event('input'));
    expect(el.value).toBe('AT61 1990 4300 2');
    // Six significant characters precede the caret (A,T,6,1,1,9 plus the
    // inserted 9 = seven), so it must not jump to the end.
    expect(el.selectionStart).toBe(8);
  });

  it('reports valid on blur', () => {
    const onState = vi.fn();
    const { el } = boundInput(onState);
    el.value = 'AT61 1904 3002 3457 3201';
    el.dispatchEvent(new Event('blur'));
    expect(onState).toHaveBeenCalledWith({
      state: 'valid', normalized: 'AT611904300234573201', issue: null,
    });
  });

  it('reports empty and invalid distinctly', () => {
    const onState = vi.fn();
    const { el } = boundInput(onState);
    el.dispatchEvent(new Event('blur'));
    expect(onState).toHaveBeenLastCalledWith(
      expect.objectContaining({ state: 'empty' }));
    el.value = 'AT61 1904 3002 3457 3202';
    el.dispatchEvent(new Event('blur'));
    expect(onState).toHaveBeenLastCalledWith(
      expect.objectContaining({ state: 'invalid', issue: 'ibanBadChecksum' }));
  });

  it('stops reporting once unbound', () => {
    const onState = vi.fn();
    const { el, unbind } = boundInput(onState);
    unbind();
    el.value = 'AT61 1904 3002 3457 3201';
    el.dispatchEvent(new Event('blur'));
    el.dispatchEvent(new Event('input'));
    expect(onState).not.toHaveBeenCalled();
  });
});
