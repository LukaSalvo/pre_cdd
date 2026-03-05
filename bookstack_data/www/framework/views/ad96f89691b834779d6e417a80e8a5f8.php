<form action="<?php echo e(url('/login')); ?>" method="POST" id="login-form" class="mt-l">
    <?php echo csrf_field(); ?>


    <div class="stretch-inputs">
        <div class="form-group">
            <label for="username"><?php echo e(trans('auth.username')); ?></label>
            <?php echo $__env->make('form.text', ['name' => 'username', 'autofocus' => true], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
        </div>

        <?php if(session('request-email', false) === true): ?>
            <div class="form-group">
                <label for="email"><?php echo e(trans('auth.email')); ?></label>
                <?php echo $__env->make('form.text', ['name' => 'email'], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
                <span class="text-neg"><?php echo e(trans('auth.ldap_email_hint')); ?></span>
            </div>
        <?php endif; ?>

        <div class="form-group">
            <label for="password"><?php echo e(trans('auth.password')); ?></label>
            <?php echo $__env->make('form.password', ['name' => 'password'], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
        </div>

        <div class="form-group text-right pt-s">
            <button class="button"><?php echo e(Str::title(trans('auth.log_in'))); ?></button>
        </div>
    </div>

</form><?php /**PATH /app/www/resources/views/auth/parts/login-form-ldap.blade.php ENDPATH**/ ?>