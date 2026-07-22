export function BrandLogo({ compact = false }: { compact?: boolean }) {
  return <div className={compact ? 'brand-logo compact' : 'brand-logo'}>V+</div>;
}
