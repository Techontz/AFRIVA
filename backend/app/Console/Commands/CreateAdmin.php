<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

/** Creates (or resets) a super admin login; the password is prompted for, never passed as an argument. */
class CreateAdmin extends Command
{
    protected $signature = 'afriva:create-admin {email} {--name=Afriva Admin}';

    protected $description = 'Create or reset a super admin account';

    public function handle(): int
    {
        $password = $this->secret('Password (min 10 characters)');
        if (strlen((string) $password) < 10) {
            $this->error('Password must be at least 10 characters.');

            return self::FAILURE;
        }
        if ($password !== $this->secret('Repeat password')) {
            $this->error('Passwords do not match.');

            return self::FAILURE;
        }

        $user = User::updateOrCreate(
            ['email' => $this->argument('email')],
            ['name' => $this->option('name'), 'password' => $password, 'role' => 'super_admin', 'staff_role' => 'owner'],
        );

        $this->info("Super admin ready: {$user->email}");

        return self::SUCCESS;
    }
}
