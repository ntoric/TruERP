'use client'

import { useEffect, useState } from 'react'
import { apiFetch } from '@/hooks/useAuth'
import DashboardLayout from '@/components/layout/DashboardLayout'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { notifyError, notifySuccess } from '@/lib/notify'
import { 
  Mail, MessageSquare, Send, Loader2, CheckCircle, XCircle, 
  Smartphone, Server, Key, Globe, Save 
} from 'lucide-react'

interface DeveloperSettings {
  id: string
  user_id: string
  email_provider: string
  smtp_host: string
  smtp_port: number
  smtp_username: string
  smtp_password?: string
  from_email: string
  from_name: string
  mailgun_domain: string
  whatsapp_provider: string
  whatsapp_api_key?: string
  whatsapp_phone_number_id: string
  whatsapp_business_account_id: string
  twilio_account_sid: string
  twilio_auth_token?: string
  twilio_phone_number: string
  sms_provider: string
  twilio_sms_account_sid: string
  twilio_sms_auth_token?: string
  twilio_sms_phone_number: string
  msg91_sender_id: string
  msg91_auth_key?: string
  textlocal_sender_id: string
  textlocal_api_key?: string
  aws_access_key: string
  aws_secret_key?: string
  aws_region: string
  sendgrid_sms_api_key?: string
}

export default function DeveloperSettingsPage() {
  const [activeTab, setActiveTab] = useState('email')
  const [settings, setSettings] = useState<DeveloperSettings>({
    id: '',
    user_id: '',
    email_provider: 'smtp',
    smtp_host: '',
    smtp_port: 587,
    smtp_username: '',
    from_email: '',
    from_name: '',
    mailgun_domain: '',
    whatsapp_provider: 'meta',
    whatsapp_phone_number_id: '',
    whatsapp_business_account_id: '',
    twilio_account_sid: '',
    twilio_phone_number: '',
    sms_provider: 'twilio',
    twilio_sms_account_sid: '',
    twilio_sms_phone_number: '',
    msg91_sender_id: '',
    textlocal_sender_id: '',
    aws_access_key: '',
    aws_region: '',
  })

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [testing, setTesting] = useState<'email' | 'whatsapp' | 'sms' | null>(null)
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null)

  useEffect(() => {
    fetchSettings()
  }, [])

  const fetchSettings = async () => {
    try {
      const res = await apiFetch('/developer-settings')
      if (res.ok) {
        const data = await res.json()
        setSettings(data)
      }
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async () => {
    setSaving(true)
    try {
      const res = await apiFetch('/developer-settings', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      })
      if (res.ok) {
        notifySuccess('Settings saved successfully')
      } else {
        notifyError('Failed to save settings')
      }
    } catch (err) {
      console.error(err)
      notifyError('Failed to save settings')
    } finally {
      setSaving(false)
    }
  }

  const testEmailConnection = async () => {
    setTesting('email')
    setTestResult(null)
    try {
      const res = await apiFetch('/developer-settings/test-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
      const data = await res.json()
      setTestResult({ success: res.ok, message: data.message || (res.ok ? 'Email connection successful' : 'Email connection failed') })
    } catch (err) {
      setTestResult({ success: false, message: 'Email connection failed' })
    } finally {
      setTesting(null)
    }
  }

  const testWhatsAppConnection = async () => {
    setTesting('whatsapp')
    setTestResult(null)
    try {
      const res = await apiFetch('/developer-settings/test-whatsapp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
      const data = await res.json()
      setTestResult({ success: res.ok, message: data.message || (res.ok ? 'WhatsApp connection successful' : 'WhatsApp connection failed') })
    } catch (err) {
      setTestResult({ success: false, message: 'WhatsApp connection failed' })
    } finally {
      setTesting(null)
    }
  }

  const testSMSConnection = async () => {
    setTesting('sms')
    setTestResult(null)
    try {
      const res = await apiFetch('/developer-settings/test-sms', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      })
      const data = await res.json()
      setTestResult({ success: res.ok, message: data.message || (res.ok ? 'SMS connection successful' : 'SMS connection failed') })
    } catch (err) {
      setTestResult({ success: false, message: 'SMS connection failed' })
    } finally {
      setTesting(null)
    }
  }

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
        </div>
      </DashboardLayout>
    )
  }

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Developer Settings</h1>
            <p className="text-gray-600">Configure email, WhatsApp, and SMS service providers</p>
          </div>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
            Save Settings
          </Button>
        </div>

        {testResult && (
          <div className={`flex items-center gap-2 p-4 rounded-lg ${testResult.success ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
            {testResult.success ? <CheckCircle className="h-5 w-5" /> : <XCircle className="h-5 w-5" />}
            {testResult.message}
          </div>
        )}

        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="email" className="flex items-center gap-2">
              <Mail className="h-4 w-4" />
              Email
            </TabsTrigger>
            <TabsTrigger value="whatsapp" className="flex items-center gap-2">
              <MessageSquare className="h-4 w-4" />
              WhatsApp
            </TabsTrigger>
            <TabsTrigger value="sms" className="flex items-center gap-2">
              <Smartphone className="h-4 w-4" />
              SMS
            </TabsTrigger>
          </TabsList>

          <TabsContent value="email">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Mail className="h-5 w-5" />
                  Email Service Configuration
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Email Provider</Label>
                    <Select
                      value={settings.email_provider}
                      onValueChange={(value) => setSettings({ ...settings, email_provider: value })}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="smtp">SMTP</SelectItem>
                        <SelectItem value="sendgrid">SendGrid</SelectItem>
                        <SelectItem value="ses">Amazon SES</SelectItem>
                        <SelectItem value="mailgun">Mailgun</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                {settings.email_provider === 'smtp' && (
                  <>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>SMTP Host</Label>
                        <Input
                          value={settings.smtp_host}
                          onChange={(e) => setSettings({ ...settings, smtp_host: e.target.value })}
                          placeholder="smtp.gmail.com"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>SMTP Port</Label>
                        <Input
                          type="number"
                          value={settings.smtp_port}
                          onChange={(e) => setSettings({ ...settings, smtp_port: parseInt(e.target.value) })}
                          placeholder="587"
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>SMTP Username</Label>
                        <Input
                          value={settings.smtp_username}
                          onChange={(e) => setSettings({ ...settings, smtp_username: e.target.value })}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>SMTP Password</Label>
                        <Input
                          type="password"
                          onChange={(e) => setSettings({ ...settings, smtp_password: e.target.value })}
                        />
                      </div>
                    </div>
                  </>
                )}

                {settings.email_provider === 'mailgun' && (
                  <div className="space-y-2">
                    <Label>Mailgun Domain</Label>
                    <Input
                      value={settings.mailgun_domain}
                      onChange={(e) => setSettings({ ...settings, mailgun_domain: e.target.value })}
                      placeholder="mg.yourdomain.com"
                    />
                  </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>From Email</Label>
                    <Input
                      value={settings.from_email}
                      onChange={(e) => setSettings({ ...settings, from_email: e.target.value })}
                      placeholder="noreply@yourdomain.com"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>From Name</Label>
                    <Input
                      value={settings.from_name}
                      onChange={(e) => setSettings({ ...settings, from_name: e.target.value })}
                      placeholder="Your Business Name"
                    />
                  </div>
                </div>

                <Button onClick={testEmailConnection} disabled={testing === 'email'} variant="outline">
                  {testing === 'email' ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Send className="mr-2 h-4 w-4" />}
                  Test Email Connection
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="whatsapp">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <MessageSquare className="h-5 w-5" />
                  WhatsApp Service Configuration
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label>WhatsApp Provider</Label>
                  <Select
                    value={settings.whatsapp_provider}
                    onValueChange={(value) => setSettings({ ...settings, whatsapp_provider: value })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="meta">Meta (WhatsApp Business API)</SelectItem>
                      <SelectItem value="twilio">Twilio</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {settings.whatsapp_provider === 'meta' && (
                  <>
                    <div className="space-y-2">
                      <Label>WhatsApp API Key</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, whatsapp_api_key: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Phone Number ID</Label>
                      <Input
                        value={settings.whatsapp_phone_number_id}
                        onChange={(e) => setSettings({ ...settings, whatsapp_phone_number_id: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Business Account ID</Label>
                      <Input
                        value={settings.whatsapp_business_account_id}
                        onChange={(e) => setSettings({ ...settings, whatsapp_business_account_id: e.target.value })}
                      />
                    </div>
                  </>
                )}

                {settings.whatsapp_provider === 'twilio' && (
                  <>
                    <div className="space-y-2">
                      <Label>Twilio Account SID</Label>
                      <Input
                        value={settings.twilio_account_sid}
                        onChange={(e) => setSettings({ ...settings, twilio_account_sid: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Twilio Auth Token</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, twilio_auth_token: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Twilio Phone Number</Label>
                      <Input
                        value={settings.twilio_phone_number}
                        onChange={(e) => setSettings({ ...settings, twilio_phone_number: e.target.value })}
                      />
                    </div>
                  </>
                )}

                <Button onClick={testWhatsAppConnection} disabled={testing === 'whatsapp'} variant="outline">
                  {testing === 'whatsapp' ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Send className="mr-2 h-4 w-4" />}
                  Test WhatsApp Connection
                </Button>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="sms">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Smartphone className="h-5 w-5" />
                  SMS Service Configuration
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label>SMS Provider</Label>
                  <Select
                    value={settings.sms_provider}
                    onValueChange={(value) => setSettings({ ...settings, sms_provider: value })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="twilio">Twilio</SelectItem>
                      <SelectItem value="msg91">Msg91</SelectItem>
                      <SelectItem value="textlocal">TextLocal</SelectItem>
                      <SelectItem value="aws_sns">AWS SNS</SelectItem>
                      <SelectItem value="sendgrid">SendGrid</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {settings.sms_provider === 'twilio' && (
                  <>
                    <div className="space-y-2">
                      <Label>Twilio Account SID</Label>
                      <Input
                        value={settings.twilio_sms_account_sid}
                        onChange={(e) => setSettings({ ...settings, twilio_sms_account_sid: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Twilio Auth Token</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, twilio_sms_auth_token: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Twilio Phone Number</Label>
                      <Input
                        value={settings.twilio_sms_phone_number}
                        onChange={(e) => setSettings({ ...settings, twilio_sms_phone_number: e.target.value })}
                      />
                    </div>
                  </>
                )}

                {settings.sms_provider === 'msg91' && (
                  <>
                    <div className="space-y-2">
                      <Label>Msg91 Auth Key</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, msg91_auth_key: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Msg91 Sender ID</Label>
                      <Input
                        value={settings.msg91_sender_id}
                        onChange={(e) => setSettings({ ...settings, msg91_sender_id: e.target.value })}
                      />
                    </div>
                  </>
                )}

                {settings.sms_provider === 'textlocal' && (
                  <>
                    <div className="space-y-2">
                      <Label>TextLocal API Key</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, textlocal_api_key: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>TextLocal Sender ID</Label>
                      <Input
                        value={settings.textlocal_sender_id}
                        onChange={(e) => setSettings({ ...settings, textlocal_sender_id: e.target.value })}
                      />
                    </div>
                  </>
                )}

                {settings.sms_provider === 'aws_sns' && (
                  <>
                    <div className="space-y-2">
                      <Label>AWS Access Key</Label>
                      <Input
                        value={settings.aws_access_key}
                        onChange={(e) => setSettings({ ...settings, aws_access_key: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>AWS Secret Key</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, aws_secret_key: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>AWS Region</Label>
                      <Input
                        value={settings.aws_region}
                        onChange={(e) => setSettings({ ...settings, aws_region: e.target.value })}
                        placeholder="us-east-1"
                      />
                    </div>
                  </>
                )}

                {settings.sms_provider === 'sendgrid' && (
                  <>
                    <div className="space-y-2">
                      <Label>SendGrid SMS API Key</Label>
                      <Input
                        type="password"
                        onChange={(e) => setSettings({ ...settings, sendgrid_sms_api_key: e.target.value })}
                      />
                    </div>
                  </>
                )}

                <Button onClick={testSMSConnection} disabled={testing === 'sms'} variant="outline">
                  {testing === 'sms' ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Send className="mr-2 h-4 w-4" />}
                  Test SMS Connection
                </Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  )
}
