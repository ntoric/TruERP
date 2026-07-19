import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { AuthProvider } from '@/hooks/useAuth'
import { Toaster } from '@/components/ui/toaster'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'MyBillBook - GST Billing Software',
  description: 'Best GST Billing Software for Small Businesses in India',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <AuthProvider>
          {children}
          <Toaster />
        </AuthProvider>
      </body>
    </html>
  )
}
