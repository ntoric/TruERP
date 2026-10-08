import React from 'react';
import {Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {
  Barcode,
  Boxes,
  CircleCheck,
  FileText,
  Gift,
  Landmark,
  LayoutTemplate,
  MonitorSmartphone,
  Receipt,
  ScanBarcode,
  Share2,
  ShoppingCart,
  Star,
  Users,
  Wallet,
  WifiOff,
} from 'lucide-react';
import {Caption, Card, KineticTitle, Row, SceneFrame, SpringIn} from '../components';
import {CAPTIONS, LIGHT, usePalette} from '../theme';

const Chip: React.FC<{icon: React.ReactNode; label: string; delay: number}> = ({
  icon,
  label,
  delay,
}) => {
  const p = usePalette();
  return (
    <SpringIn delay={delay}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          background: p.card,
          border: `1px solid ${p.cardBorder}`,
          borderRadius: 999,
          padding: '14px 28px',
          fontSize: 26,
          fontWeight: 600,
        }}
      >
        <span style={{color: p.crimson, display: 'flex'}}>{icon}</span>
        {label}
      </div>
    </SpringIn>
  );
};

const Line: React.FC<{width: number | string; delay: number; highlight?: boolean}> = ({
  width,
  delay,
  highlight,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = usePalette();
  const s = spring({frame: frame - delay, fps, config: {damping: 16}});
  return (
    <div
      style={{
        height: 22,
        width,
        borderRadius: 8,
        transform: `scaleX(${s})`,
        transformOrigin: 'left',
        background: highlight ? p.crimson : p.barNeutral,
      }}
    />
  );
};

export const Scene1Intro: React.FC = () => {
  return (
    <SceneFrame>
      <div
        style={{
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 48,
          paddingBottom: 120,
        }}
      >
        <SpringIn>
          <Img
            src={staticFile('logo.png')}
            style={{height: 150, objectFit: 'contain'}}
          />
        </SpringIn>
        <KineticTitle
          words={['Sell.', 'Stock.', 'Manage.']}
          delay={20}
          accent={[2]}
        />
        <Row style={{gap: 20}}>
          <Chip icon={<Receipt size={28} />} label="Billing" delay={40} />
          <Chip icon={<Boxes size={28} />} label="Inventory" delay={48} />
          <Chip icon={<Users size={28} />} label="Payroll" delay={56} />
          <Chip icon={<Gift size={28} />} label="Loyalty" delay={64} />
        </Row>
      </div>
      <Caption text={CAPTIONS[0]} />
    </SceneFrame>
  );
};

export const Scene2Invoice: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = usePalette();
  const tax = interpolate(frame, [100, 140], [0, 1800], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const pop = spring({frame: frame - 150, fps, config: {damping: 12}});
  return (
    <SceneFrame>
      <div style={{display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', gap: 80, paddingBottom: 110}}>
        <SpringIn>
          <Card style={{width: 620}}>
            <Row style={{justifyContent: 'space-between', marginBottom: 24}}>
              <Row>
                <FileText size={36} color={p.crimson} />
                <div>
                  <div style={{fontSize: 30, fontWeight: 700}}>Tax Invoice</div>
                  <div style={{fontSize: 20, color: p.muted}}>INV-0241 · GSTIN added</div>
                </div>
              </Row>
              <div style={{fontSize: 22, color: p.green, fontWeight: 700}}>GST ✓</div>
            </Row>
            {['Cotton Kurta — Size M', 'Wireless Mouse', 'Notebook A5 × 3'].map((item, i) => (
              <SpringIn key={item} delay={20 + i * 14}>
                <Row style={{justifyContent: 'space-between', padding: '14px 0', borderBottom: `1px solid ${p.cardBorder}`}}>
                  <span style={{fontSize: 24}}>{item}</span>
                  <span style={{fontSize: 24, color: p.muted}}>₹{(i + 2) * 1250}</span>
                </Row>
              </SpringIn>
            ))}
            <Row style={{justifyContent: 'space-between', marginTop: 20}}>
              <span style={{fontSize: 24, color: p.muted}}>GST auto-calculated</span>
              <span style={{fontSize: 30, fontWeight: 700, color: p.crimson}}>
                ₹{Math.round(tax).toLocaleString('en-IN')}
              </span>
            </Row>
          </Card>
        </SpringIn>
        <div style={{display: 'flex', flexDirection: 'column', gap: 28, transform: `scale(${pop})`}}>
          <Chip icon={<LayoutTemplate size={30} />} label="Customizable templates" delay={80} />
          <Chip icon={<Share2 size={30} />} label="Share PDF instantly" delay={95} />
          <Chip icon={<Landmark size={30} />} label="E-invoice ready" delay={110} />
        </div>
      </div>
      <Caption text={CAPTIONS[1]} />
    </SceneFrame>
  );
};

export const Scene3POS: React.FC = () => {
  const frame = useCurrentFrame();
  const p = usePalette();
  const scanX = interpolate(frame, [40, 90, 140], [0, 560, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const items = ['Parle-G Biscuit', 'Amul Milk 1L', 'Basmati Rice 5kg'];
  return (
    <SceneFrame>
      <div style={{display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', gap: 90, paddingBottom: 110}}>
        <SpringIn>
          <Card style={{width: 640, position: 'relative', overflow: 'hidden'}}>
            <Row style={{marginBottom: 20}}>
              <ShoppingCart size={36} color={p.crimson} />
              <div style={{fontSize: 30, fontWeight: 700}}>Point of Sale</div>
            </Row>
            {items.map((item, i) => {
              const appear = frame > 50 + i * 30;
              return (
                <Row
                  key={item}
                  style={{
                    justifyContent: 'space-between',
                    padding: '14px 0',
                    borderBottom: `1px solid ${p.cardBorder}`,
                    opacity: appear ? 1 : 0.25,
                  }}
                >
                  <span style={{fontSize: 24}}>{item}</span>
                  <span style={{fontSize: 24, color: appear ? p.text : p.muted}}>
                    {appear ? `₹${(i + 1) * 350}` : '—'}
                  </span>
                </Row>
              );
            })}
            <div
              style={{
                position: 'absolute',
                top: 80,
                bottom: 20,
                left: 32 + scanX,
                width: 3,
                background: p.crimson,
                boxShadow: `0 0 24px ${p.crimson}`,
              }}
            />
          </Card>
        </SpringIn>
        <div style={{display: 'flex', flexDirection: 'column', gap: 28}}>
          <Chip icon={<ScanBarcode size={30} />} label="Scan barcodes" delay={30} />
          <Chip icon={<FileText size={30} />} label="Hold bills as drafts" delay={60} />
          <Chip icon={<Wallet size={30} />} label="Cash sessions" delay={90} />
          <Chip icon={<WifiOff size={30} />} label="Works offline" delay={120} />
        </div>
      </div>
      <Caption text={CAPTIONS[2]} />
    </SceneFrame>
  );
};

export const Scene4Inventory: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const p = usePalette();
  const print = interpolate(frame, [90, 160], [-30, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const stocks = [82, 45, 96, 30];
  return (
    <SceneFrame>
      <div style={{display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', gap: 90, paddingBottom: 110}}>
        <SpringIn>
          <Card style={{width: 560}}>
            <Row style={{marginBottom: 24}}>
              <Boxes size={36} color={p.crimson} />
              <div style={{fontSize: 30, fontWeight: 700}}>Live Stock</div>
            </Row>
            {['Store A', 'Store B', 'Warehouse', 'Store C'].map((name, i) => {
              const w = spring({frame: frame - 20 - i * 10, fps, config: {damping: 18}});
              return (
                <div key={name} style={{marginBottom: 20}}>
                  <Row style={{justifyContent: 'space-between', marginBottom: 8}}>
                    <span style={{fontSize: 22}}>{name}</span>
                    <span style={{fontSize: 22, color: p.muted}}>{stocks[i]} units</span>
                  </Row>
                  <div style={{height: 14, background: p.track, borderRadius: 8}}>
                    <div
                      style={{
                        height: '100%',
                        width: `${stocks[i] * w}%`,
                        borderRadius: 8,
                        background: i === 2 ? p.crimson : p.barNeutral,
                      }}
                    />
                  </div>
                </div>
              );
            })}
          </Card>
        </SpringIn>
        <SpringIn delay={50}>
          <Card style={{width: 460, textAlign: 'center'}}>
            <Row style={{justifyContent: 'center', marginBottom: 20}}>
              <Barcode size={36} color={p.crimson} />
              <div style={{fontSize: 28, fontWeight: 700}}>Barcode Labels</div>
            </Row>
            <div
              style={{
                background: p.labelPaper,
                border: p === LIGHT ? `1px solid ${p.cardBorder}` : 'none',
                borderRadius: 12,
                padding: '24px 20px',
                transform: `translateY(${print}px)`,
                color: p.labelInk,
              }}
            >
              <div style={{fontSize: 18, fontWeight: 700}}>Cotton Kurta — M</div>
              <div style={{display: 'flex', justifyContent: 'center', gap: 3, margin: '14px 0'}}>
                {Array.from({length: 34}).map((_, i) => (
                  <div
                    key={i}
                    style={{
                      width: i % 4 === 0 ? 4 : 2,
                      height: 56,
                      background: p.labelInk,
                    }}
                  />
                ))}
              </div>
              <div style={{fontSize: 16, fontWeight: 600}}>₹1,499 · SKU 88412</div>
            </div>
            <div style={{marginTop: 20, fontSize: 22, color: p.muted}}>
              Thermal printers · A4 sheets
            </div>
          </Card>
        </SpringIn>
      </div>
      <Caption text={CAPTIONS[3]} />
    </SceneFrame>
  );
};

export const Scene5Payroll: React.FC = () => {
  const frame = useCurrentFrame();
  const p = usePalette();
  const paid = spring({
    frame: frame - 140,
    fps: 30,
    config: {damping: 11},
  });
  return (
    <SceneFrame>
      <div style={{display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', gap: 90, paddingBottom: 110}}>
        <SpringIn>
          <Card style={{width: 560}}>
            <Row style={{marginBottom: 24}}>
              <Users size={36} color={p.crimson} />
              <div style={{fontSize: 30, fontWeight: 700}}>Attendance</div>
            </Row>
            <div style={{display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 12}}>
              {Array.from({length: 28}).map((_, i) => {
                const on = frame > 30 + i * 2;
                return (
                  <div
                    key={i}
                    style={{
                      height: 52,
                      borderRadius: 10,
                      background: on ? (i % 9 === 4 ? p.crimson : p.green) : p.track,
                    }}
                  />
                );
              })}
            </div>
            <div style={{marginTop: 16, fontSize: 20, color: p.muted}}>
              Present · Leave tracked automatically
            </div>
          </Card>
        </SpringIn>
        <SpringIn delay={60}>
          <Card style={{width: 520, position: 'relative'}}>
            <Row style={{marginBottom: 20}}>
              <FileText size={36} color={p.crimson} />
              <div style={{fontSize: 30, fontWeight: 700}}>Payslip — Sept</div>
            </Row>
            <Line width="80%" delay={80} />
            <div style={{height: 14}} />
            <Line width="65%" delay={90} />
            <div style={{height: 14}} />
            <Line width="72%" delay={100} />
            <Row style={{justifyContent: 'space-between', marginTop: 28}}>
              <span style={{fontSize: 24, color: p.muted}}>Net pay</span>
              <span style={{fontSize: 34, fontWeight: 800}}>₹42,500</span>
            </Row>
            <div
              style={{
                position: 'absolute',
                right: 28,
                top: 24,
                border: `3px solid ${p.green}`,
                color: p.green,
                borderRadius: 10,
                padding: '6px 16px',
                fontSize: 22,
                fontWeight: 800,
                transform: `scale(${paid}) rotate(-12deg)`,
                opacity: paid,
              }}
            >
              PAID
            </div>
            <Row style={{marginTop: 18, gap: 10}}>
              <CircleCheck size={22} color={p.green} />
              <span style={{fontSize: 20, color: p.muted}}>Advance deducted · payment logged</span>
            </Row>
          </Card>
        </SpringIn>
      </div>
      <Caption text={CAPTIONS[4]} />
    </SceneFrame>
  );
};

export const Scene6Loyalty: React.FC = () => {
  const frame = useCurrentFrame();
  const p = usePalette();
  const points = Math.round(
    interpolate(frame, [30, 130], [0, 2450], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    })
  );
  return (
    <SceneFrame>
      <div style={{display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', gap: 90, paddingBottom: 110}}>
        <SpringIn>
          <Card style={{width: 560, textAlign: 'center'}}>
            <Row style={{justifyContent: 'center', marginBottom: 12}}>
              <Gift size={40} color={p.crimson} />
              <div style={{fontSize: 30, fontWeight: 700}}>Loyalty Points</div>
            </Row>
            <div style={{fontSize: 110, fontWeight: 800, color: p.crimson, lineHeight: 1.1}}>
              {points.toLocaleString('en-IN')}
            </div>
            <div style={{fontSize: 24, color: p.muted}}>pts earned on every purchase</div>
            <Row style={{justifyContent: 'center', marginTop: 26, gap: 8}}>
              {Array.from({length: 5}).map((_, i) => (
                <Star
                  key={i}
                  size={40}
                  fill={frame > 80 + i * 8 ? p.crimson : 'none'}
                  color={frame > 80 + i * 8 ? p.crimson : p.starOff}
                />
              ))}
            </Row>
          </Card>
        </SpringIn>
        <div style={{display: 'flex', flexDirection: 'column', gap: 28}}>
          <Chip icon={<ShoppingCart size={30} />} label="Earn at checkout" delay={40} />
          <Chip icon={<CircleCheck size={30} />} label="Redeem instantly" delay={70} />
          <Chip icon={<Users size={30} />} label="Turn shoppers into regulars" delay={100} />
        </div>
      </div>
      <Caption text={CAPTIONS[5]} />
    </SceneFrame>
  );
};

export const Scene7Outro: React.FC = () => {
  const p = usePalette();
  return (
    <SceneFrame>
      <div
        style={{
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 44,
          paddingBottom: 120,
        }}
      >
        <SpringIn>
          <Img src={staticFile('logo.png')} style={{height: 180, objectFit: 'contain'}} />
        </SpringIn>
        <SpringIn delay={15}>
          <div style={{fontSize: 44, fontWeight: 600, color: p.muted}}>
            TruERP — GST Billing Software
          </div>
        </SpringIn>
        <Row style={{gap: 20}}>
          <Chip icon={<MonitorSmartphone size={28} />} label="Web" delay={40} />
          <Chip icon={<MonitorSmartphone size={28} />} label="Mac" delay={50} />
          <Chip icon={<MonitorSmartphone size={28} />} label="Windows" delay={60} />
        </Row>
        <SpringIn delay={80}>
          <div style={{fontSize: 34, fontWeight: 700, color: p.crimson}}>
            Simplify your business today.
          </div>
        </SpringIn>
      </div>
      <Caption text={CAPTIONS[6]} />
    </SceneFrame>
  );
};
