import React, { useState } from 'react';
import { UserProfile, NavPage } from '../types';
import {
  User,
  ShieldCheck,
  Building2,
  Lock,
  Eye,
  EyeOff,
  LogOut,
  Edit2,
} from 'lucide-react';

interface ProfileViewProps {
  user: UserProfile;
  onUpdateProfile: (profile: UserProfile) => void;
  onNavigate: (page: NavPage) => void;
  onTriggerToast: (type: 'success' | 'error' | 'info', text: string) => void;
}

export const ProfileView: React.FC<ProfileViewProps> = ({
  user,
  onUpdateProfile,
  onNavigate,
  onTriggerToast,
}) => {
  const [name, setName] = useState(user.name);
  const [email, setEmail] = useState(user.email);
  const [department, setDepartment] = useState(user.department);
  const [avatarUrl, setAvatarUrl] = useState(user.avatarUrl);

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const handleSaveProfile = () => {
    if (!name.trim() || !email.trim()) {
      onTriggerToast('error', 'Name and Email cannot be empty.');
      return;
    }

    const updated: UserProfile = {
      ...user,
      name: name.trim(),
      email: email.trim(),
      department,
      avatarUrl: avatarUrl.trim(),
    };

    onUpdateProfile(updated);
    onTriggerToast('success', 'Profile settings updated successfully!');
  };

  const handleUpdatePassword = () => {
    if (!currentPassword) {
      onTriggerToast('error', 'Please enter your current password.');
      return;
    }
    if (newPassword.length < 6) {
      onTriggerToast('error', 'New password must be at least 6 characters.');
      return;
    }
    if (newPassword !== confirmPassword) {
      onTriggerToast('error', 'New passwords do not match.');
      return;
    }

    onTriggerToast('success', 'Password updated successfully!');
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
  };

  return (
    <div className="max-w-3xl mx-auto space-y-8 animate-fadeIn">
      {/* Profile Header Card */}
      <div className="bg-surface-container-lowest rounded-xl card-shadow p-card-padding border border-outline-variant flex flex-col md:flex-row items-center gap-6">
        <div className="relative group shrink-0">
          <div className="w-24 h-24 md:w-28 md:h-28 rounded-full overflow-hidden border-4 border-surface bg-surface-container-high shadow-sm">
            <img src={avatarUrl} alt={name} className="w-full h-full object-cover" />
          </div>

          <button
            onClick={() => {
              const newUrl = prompt('Enter new avatar Image URL:', avatarUrl);
              if (newUrl) setAvatarUrl(newUrl.trim());
            }}
            className="absolute bottom-0 right-0 bg-primary text-on-primary w-8 h-8 rounded-full flex items-center justify-center shadow-md hover:bg-primary-container transition-colors border-2 border-surface cursor-pointer"
            title="Change Avatar Picture"
          >
            <Edit2 className="w-4 h-4" />
          </button>
        </div>

        <div className="text-center md:text-left flex-grow">
          <h2 className="font-headline-md text-headline-md md:font-display-lg md:text-display-lg text-on-surface font-bold">
            {name}
          </h2>
          <p className="font-body-md text-body-md text-secondary mt-1">{user.role}</p>

          <div className="mt-3 flex flex-wrap justify-center md:justify-start gap-2">
            <span className="inline-flex items-center gap-1 bg-surface-container-low text-primary px-3 py-1 rounded-full font-label-caps text-label-caps border border-surface-variant font-bold">
              <ShieldCheck className="w-3.5 h-3.5" /> Super Admin
            </span>
            <span className="inline-flex items-center gap-1 bg-surface-container-low text-secondary px-3 py-1 rounded-full font-label-caps text-label-caps border border-surface-variant font-medium">
              <Building2 className="w-3.5 h-3.5" /> {department}
            </span>
          </div>
        </div>
      </div>

      {/* Admin Personal Information Form */}
      <div className="bg-surface-container-lowest rounded-xl card-shadow border border-outline-variant overflow-hidden">
        <div className="bg-surface-container-low px-card-padding py-4 border-b border-outline-variant">
          <h3 className="font-title-sm text-title-sm text-on-surface flex items-center gap-2 font-semibold">
            <User className="w-5 h-5 text-primary" /> Personal Information
          </h3>
        </div>

        <form className="p-card-padding space-y-6" onSubmit={(e) => e.preventDefault()}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">Full Name</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 font-body-md text-body-md text-on-surface focus:outline-none focus:border-primary"
              />
            </div>

            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">Email Address</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 font-body-md text-body-md text-on-surface focus:outline-none focus:border-primary"
              />
            </div>

            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">Role</label>
              <input
                type="text"
                value={user.role}
                disabled
                className="w-full bg-surface-container border border-outline-variant rounded-lg px-4 py-2.5 font-body-md text-body-md text-secondary cursor-not-allowed"
              />
            </div>

            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">Department</label>
              <select
                value={department}
                onChange={(e) => setDepartment(e.target.value)}
                className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 font-body-md text-body-md text-on-surface focus:outline-none focus:border-primary cursor-pointer"
              >
                <option value="IT Department">IT Department</option>
                <option value="Human Resources">Human Resources</option>
                <option value="Operations">Operations</option>
                <option value="Security Oversight">Security Oversight</option>
              </select>
            </div>
          </div>

          <div className="flex justify-end pt-4 border-t border-outline-variant">
            <button
              type="button"
              onClick={handleSaveProfile}
              className="bg-primary text-on-primary font-title-sm text-title-sm px-6 py-2.5 rounded-lg hover:bg-primary-container transition-all shadow-sm cursor-pointer font-semibold"
            >
              Save Changes
            </button>
          </div>
        </form>
      </div>

      {/* Password Change Section */}
      <div className="bg-surface-container-lowest rounded-xl card-shadow border border-outline-variant overflow-hidden">
        <div className="bg-surface-container-low px-card-padding py-4 border-b border-outline-variant">
          <h3 className="font-title-sm text-title-sm text-on-surface flex items-center gap-2 font-semibold">
            <Lock className="w-5 h-5 text-primary" /> Security
          </h3>
        </div>

        <form className="p-card-padding space-y-6" onSubmit={(e) => e.preventDefault()}>
          <div className="max-w-md space-y-4">
            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">Current Password</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={currentPassword}
                  onChange={(e) => setCurrentPassword(e.target.value)}
                  className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 pr-10 font-body-md"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-3 text-secondary"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">New Password</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 pr-10 font-body-md"
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="font-label-caps text-label-caps text-secondary block uppercase">Confirm New Password</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="w-full bg-surface border border-outline-variant rounded-lg px-4 py-2.5 pr-10 font-body-md"
                />
              </div>
            </div>
          </div>

          <div className="flex justify-start pt-4 border-t border-outline-variant">
            <button
              type="button"
              onClick={handleUpdatePassword}
              className="bg-secondary text-on-secondary font-title-sm text-title-sm px-6 py-2.5 rounded-lg hover:bg-slate-700 transition-all cursor-pointer font-semibold"
            >
              Update Password
            </button>
          </div>
        </form>
      </div>

      {/* Danger Zone (Sign Out) */}
      <div className="pt-4 pb-12 flex justify-end">
        <button
          onClick={() => {
            onTriggerToast('info', 'Signed out session.');
            onNavigate('login');
          }}
          className="flex items-center gap-2 bg-error-container text-error font-title-sm text-title-sm px-8 py-3 rounded-lg border border-error hover:bg-error hover:text-on-error transition-colors shadow-sm cursor-pointer font-semibold"
        >
          <LogOut className="w-5 h-5" /> Sign Out Session
        </button>
      </div>
    </div>
  );
};
