<?php

namespace App\Support;

/**
 * Staff roles (scope §05 "Roles & records") and what each may do in the admin dashboard.
 */
class Permissions
{
    public const ROLES = ['owner', 'editor', 'reviewer', 'finance'];

    public const ALL = [
        'dashboard', 'content', 'review', 'publish', 'creators', 'reports', 'finance', 'analytics', 'users', 'settings', 'staff', 'audit',
    ];

    /** @var array<string,list<string>> */
    protected const MAP = [
        'editor' => ['dashboard', 'content', 'publish', 'creators', 'reports', 'analytics'],
        'reviewer' => ['dashboard', 'review', 'reports'],
        'finance' => ['dashboard', 'finance', 'analytics'],
    ];

    /** @return list<string> */
    public static function for(?string $role): array
    {
        if ($role === null) {
            return [];
        }

        return $role === 'owner' ? self::ALL : (self::MAP[$role] ?? []);
    }

    public static function allows(?string $role, string $permission): bool
    {
        return in_array($permission, self::for($role), true);
    }
}
