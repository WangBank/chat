import type { CSSProperties } from 'react';

type BrandMarkProps = {
  size?: number;
  className?: string;
  decorative?: boolean;
};

export default function BrandMark({ size = 36, className, decorative = false }: BrandMarkProps) {
  const style: CSSProperties = { width: size, height: size };

  return (
    <svg
      className={className}
      style={style}
      viewBox="0 0 48 48"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role={decorative ? undefined : 'img'}
      aria-label={decorative ? undefined : 'Love Chat'}
      aria-hidden={decorative || undefined}
    >
      <rect width="48" height="48" rx="14" fill="#197FB8" />
      <path d="M12.5 15.5C12.5 12.739 14.739 10.5 17.5 10.5H30.5C33.261 10.5 35.5 12.739 35.5 15.5V25.5C35.5 28.261 33.261 30.5 30.5 30.5H23L17.25 36V30.5H17.5C14.739 30.5 12.5 28.261 12.5 25.5V15.5Z" fill="white" fillOpacity="0.97" />
      <path d="M18 21.25H20.25L22.35 18.5L25.3 24.5L27.35 21.25H30" stroke="#197FB8" strokeWidth="2.15" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="17.9" cy="16.8" r="1.15" fill="#73C5ED" />
      <circle cx="30.1" cy="16.8" r="1.15" fill="#73C5ED" />
    </svg>
  );
}
