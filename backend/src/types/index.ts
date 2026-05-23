export type UserRole = 'super_admin' | 'school_admin' | 'teacher' | 'parent';
export type UserType = 'parent' | 'teacher' | 'admin';
export interface JwtPayload {
  sub: string; school_id: string; role: UserRole;
  user_type: UserType; jti: string; iat?: number; exp?: number;
}
export interface AuthenticatedUser {
  id: string; school_id: string; role: UserRole; user_type: UserType; jti: string;
}
export interface ApiResponse<T = unknown> {
  success: boolean; data?: T; error?: string; message?: string;
  meta?: { page?: number; limit?: number; total?: number; cursor?: string };
}
export interface School {
  id: string; name: string; subdomain: string;
  plan: 'starter' | 'growth' | 'enterprise'; is_active: boolean;
  settings: Record<string, unknown>; created_at: Date;
}
export interface Parent { id: string; school_id: string; full_name: string; mobile: string; }
export interface Teacher { id: string; school_id: string; full_name: string; mobile: string; }
export interface Student { id: string; school_id: string; class_id: string; admission_no: string; full_name: string; }