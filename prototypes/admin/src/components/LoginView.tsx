import React, { useState, useRef } from 'react';
import {
  User,
  Lock,
  Eye,
  EyeOff,
  ArrowRight,
  ShieldCheck,
  ArrowLeft,
  KeyRound,
} from 'lucide-react';

interface LoginViewProps {
  onLoginSuccess: () => void;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const LoginView: React.FC<LoginViewProps> = ({
  onLoginSuccess,
  onTriggerToast,
}) => {
  const [step, setStep] = useState<'credentials' | 'otp'>('credentials');
  const [username, setUsername] = useState('admin@lgu.gov');
  const [password, setPassword] = useState('••••••••');
  const [showPassword, setShowPassword] = useState(false);
  const [otp, setOtp] = useState(['5', '8', '2', '9', '1', '0']);

  const otpRefs = [
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
    useRef<HTMLInputElement>(null),
  ];

  const handleOtpChange = (index: number, value: string) => {
    if (value.length > 1) value = value[value.length - 1];
    const newOtp = [...otp];
    newOtp[index] = value;
    setOtp(newOtp);

    if (value && index < 5) {
      otpRefs[index + 1].current?.focus();
    }
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      otpRefs[index - 1].current?.focus();
    }
  };

  const handleCredentialsSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim()) {
      onTriggerToast('error', 'Please enter your Admin Username or ID.');
      return;
    }
    if (!password) {
      onTriggerToast('error', 'Please enter your Password.');
      return;
    }

    onTriggerToast('info', 'Credentials verified. Please enter the 6-digit Secure OTP.');
    setStep('otp');
  };

  const handleOtpSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const enteredOtp = otp.join('');
    if (enteredOtp.length < 6) {
      onTriggerToast('error', 'Please enter the complete 6-digit OTP code.');
      return;
    }

    onTriggerToast('success', 'Authenticated successfully as Admin!');
    onLoginSuccess();
  };

  const handleResendOtp = () => {
    onTriggerToast('info', `A new OTP code has been sent to ${username}.`);
  };

  const logoUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAUEr0T_1Ag6rV0CuGvr3Y3TCteUD20RNf1y9vaC757xzVpYoQZVWh3cta4PJY3PCWqnN2fK9FuU3KgkE41TwAP16eoOXQzk10P-hyi3wtxIYsiktScR44Jb3n4DNwGSxG1CaLPv2wqpkmqf_LAio0Ss4klhFXB7r9m2FVaeNdi7ZC0NqjFi8mUzIFDprRuPAY31M1LIuMa2VVwWp7tNkBrKO9mv5Gf5gyM3g48-COAi6FkIxxAu2HEbQ-jnVa9mepx8ObII8kffOqJ';

  return (
    <div className="min-h-screen bg-[#EFF6FF] flex items-center justify-center p-margin-mobile md:p-margin-desktop font-body-md text-on-surface relative overflow-hidden">
      {/* Background Pattern */}
      <div
        className="fixed inset-0 pointer-events-none opacity-20"
        style={{
          backgroundImage:
            'radial-gradient(#b8c4ff 1px, transparent 1px)',
          backgroundSize: '32px 32px',
        }}
      />

      <div className="relative w-full max-w-[420px] bg-surface-container-lowest rounded-xl border border-outline-variant shadow-xl overflow-hidden z-10 animate-fadeIn">
        {/* Accent Bar */}
        <div className="h-[6px] w-full bg-primary" />

        <div className="p-card-padding md:p-margin-desktop flex flex-col gap-6">
          {step === 'credentials' ? (
            <>
              {/* Header & Logo */}
              <div className="flex flex-col items-center text-center gap-3">
                <div className="w-[72px] h-[72px] rounded-full border-2 border-primary/20 flex items-center justify-center bg-surface overflow-hidden shadow-sm">
                  <img src={logoUrl} alt="BantayGawa Emblem" className="w-full h-full object-cover" />
                </div>

                <div>
                  <h1 className="font-headline-md text-headline-md font-bold text-primary">
                    BantayGawaMobile
                  </h1>
                  <p className="font-body-sm text-body-sm text-secondary mt-1">
                    Admin Portal Authentication
                  </p>
                </div>
              </div>

              {/* Step 1: Login Form */}
              <form onSubmit={handleCredentialsSubmit} className="flex flex-col gap-4">
                {/* Username */}
                <div className="flex flex-col gap-1">
                  <label className="font-label-caps text-label-caps text-on-surface-variant uppercase font-bold">
                    Username / Admin ID
                  </label>
                  <div className="relative">
                    <User className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-secondary pointer-events-none" />
                    <input
                      type="text"
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      placeholder="Enter your ID"
                      className="w-full h-[48px] pl-10 pr-4 bg-surface rounded-lg border border-outline-variant text-body-md text-on-surface focus:outline-none focus:border-primary font-medium"
                    />
                  </div>
                </div>

                {/* Password */}
                <div className="flex flex-col gap-1">
                  <div className="flex justify-between items-center">
                    <label className="font-label-caps text-label-caps text-on-surface-variant uppercase font-bold">
                      Password
                    </label>
                    <button
                      type="button"
                      onClick={() => onTriggerToast('info', 'Password reset instructions sent to admin email.')}
                      className="font-label-caps text-label-caps text-primary hover:text-primary-container transition-colors"
                    >
                      Forgot?
                    </button>
                  </div>

                  <div className="relative">
                    <Lock className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-secondary pointer-events-none" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      className="w-full h-[48px] pl-10 pr-10 bg-surface rounded-lg border border-outline-variant text-body-md text-on-surface focus:outline-none focus:border-primary"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-secondary hover:text-primary"
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                {/* Submit Action */}
                <div className="flex flex-col gap-3 mt-2">
                  <button
                    type="submit"
                    className="w-full h-[48px] bg-primary hover:bg-primary-container text-on-primary font-title-sm text-title-sm font-bold rounded-lg shadow-sm hover:shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                  >
                    Log In <ArrowRight className="w-5 h-5" />
                  </button>
                </div>
              </form>
            </>
          ) : (
            <>
              {/* Header for OTP Verification */}
              <div className="flex flex-col items-center text-center gap-3">
                <div className="w-[64px] h-[64px] rounded-full border-2 border-primary/20 flex items-center justify-center bg-primary-fixed text-primary shadow-sm">
                  <KeyRound className="w-8 h-8" />
                </div>

                <div>
                  <h1 className="font-headline-md text-headline-md font-bold text-primary flex items-center justify-center gap-1.5">
                    <ShieldCheck className="w-6 h-6 text-primary" /> Secure Verification
                  </h1>
                  <p className="font-body-sm text-body-sm text-secondary mt-1 max-w-[320px]">
                    Enter the 6-digit OTP security code sent to{' '}
                    <span className="font-semibold text-on-surface">{username}</span>
                  </p>
                </div>
              </div>

              {/* Step 2: OTP Verification Form */}
              <form onSubmit={handleOtpSubmit} className="flex flex-col gap-5">
                <div className="flex flex-col gap-2">
                  <label className="font-label-caps text-label-caps text-on-surface-variant uppercase font-bold text-center">
                    Enter OTP Code
                  </label>
                  <div className="flex gap-2 justify-center">
                    {otp.map((val, idx) => (
                      <input
                        key={idx}
                        ref={otpRefs[idx]}
                        type="text"
                        maxLength={1}
                        value={val}
                        onChange={(e) => handleOtpChange(idx, e.target.value)}
                        onKeyDown={(e) => handleOtpKeyDown(idx, e)}
                        placeholder="•"
                        className="w-[48px] h-[48px] text-center font-data-mono text-title-sm font-bold bg-surface rounded-lg border border-outline-variant focus:border-primary focus:ring-2 focus:ring-primary/20 focus:outline-none transition-all"
                      />
                    ))}
                  </div>
                </div>

                <div className="text-center">
                  <button
                    type="button"
                    onClick={handleResendOtp}
                    className="font-body-sm text-[13px] text-primary hover:underline font-medium"
                  >
                    Didn't receive code? Resend OTP
                  </button>
                </div>

                {/* Actions */}
                <div className="flex flex-col gap-3">
                  <button
                    type="submit"
                    className="w-full h-[48px] bg-primary hover:bg-primary-container text-on-primary font-title-sm text-title-sm font-bold rounded-lg shadow-sm hover:shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
                  >
                    Verify & Complete Login <ArrowRight className="w-5 h-5" />
                  </button>

                  <button
                    type="button"
                    onClick={() => setStep('credentials')}
                    className="w-full h-[40px] text-secondary hover:text-on-surface font-body-sm font-medium transition-colors flex items-center justify-center gap-1.5 cursor-pointer"
                  >
                    <ArrowLeft className="w-4 h-4" /> Back to Login Credentials
                  </button>
                </div>
              </form>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

