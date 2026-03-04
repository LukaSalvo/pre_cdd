<div class="entity-meta">
    <?php if($entity->isA('revision')): ?>
        <div class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('history'))->toHtml(); ?>
            <div>
                <?php echo e(trans('entities.pages_revision')); ?>

                <?php echo e(trans('entities.pages_revisions_number')); ?><?php echo e($entity->revision_number == 0 ? '' : $entity->revision_number); ?>

            </div>
        </div>
    <?php endif; ?>

    <?php if($entity->isA('page')): ?>
        <a href="<?php echo e($entity->getUrl('/revisions')); ?>" class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('history'))->toHtml(); ?><?php echo e(trans('entities.meta_revision', ['revisionCount' => $entity->revision_count])); ?>

        </a>
    <?php endif; ?>

    <?php if($entity->ownedBy && $entity->owned_by !== $entity->created_by): ?>
        <div class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('user'))->toHtml(); ?>
            <div>
                <?php echo trans('entities.meta_owned_name', [
                    'user' => "<a href='{$entity->ownedBy->getProfileUrl()}'>".e($entity->ownedBy->name). "</a>"
                ]); ?>

            </div>
        </div>
    <?php endif; ?>

    <?php if($entity->createdBy): ?>
        <div class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('star'))->toHtml(); ?>
            <div>
                <?php echo trans('entities.meta_created_name', [
                    'timeLength' => '<span title="'. $dates->absolute($entity->created_at) .'">'. $dates->relative($entity->created_at) . '</span>',
                    'user' => "<a href='{$entity->createdBy->getProfileUrl()}'>".e($entity->createdBy->name). "</a>"
                ]); ?>

            </div>
        </div>
    <?php else: ?>
        <div class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('star'))->toHtml(); ?>
            <span title="<?php echo e($dates->absolute($entity->created_at)); ?>"><?php echo e(trans('entities.meta_created', ['timeLength' => $dates->relative($entity->created_at)])); ?></span>
        </div>
    <?php endif; ?>

    <?php if($entity->updatedBy): ?>
        <div class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('edit'))->toHtml(); ?>
            <div>
                <?php echo trans('entities.meta_updated_name', [
                    'timeLength' => '<span title="' . $dates->absolute($entity->updated_at) .'">' . $dates->relative($entity->updated_at) .'</span>',
                    'user' => "<a href='{$entity->updatedBy->getProfileUrl()}'>".e($entity->updatedBy->name). "</a>"
                ]); ?>

            </div>
        </div>
    <?php elseif(!$entity->isA('revision')): ?>
        <div class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('edit'))->toHtml(); ?>
            <span title="<?php echo e($dates->absolute($entity->updated_at)); ?>"><?php echo e(trans('entities.meta_updated', ['timeLength' => $dates->relative($entity->updated_at)])); ?></span>
        </div>
    <?php endif; ?>

    <?php if($referenceCount ?? 0): ?>
        <a href="<?php echo e($entity->getUrl('/references')); ?>" class="entity-meta-item">
            <?php echo (new \BookStack\Util\SvgIcon('reference'))->toHtml(); ?>
            <div>
                <?php echo e(trans_choice('entities.meta_reference_count', $referenceCount, ['count' => $referenceCount])); ?>

            </div>
        </a>
    <?php endif; ?>

    <?php if($watchOptions?->canWatch()): ?>
        <?php if($watchOptions->isWatching()): ?>
            <?php echo $__env->make('entities.watch-controls', [
                'entity' => $entity,
                'watchLevel' => $watchOptions->getWatchLevel(),
                'label' => trans('entities.watch_detail_' . $watchOptions->getWatchLevel()),
                'ignoring' => $watchOptions->getWatchLevel() === 'ignore',
            ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
        <?php elseif($watchedParent = $watchOptions->getWatchedParent()): ?>
            <?php echo $__env->make('entities.watch-controls', [
                'entity' => $entity,
                'watchLevel' => $watchOptions->getWatchLevel(),
                'label' => trans('entities.watch_detail_parent_' . $watchedParent->type . ($watchedParent->ignoring() ? '_ignore' : '')),
                'ignoring' => $watchedParent->ignoring(),
            ], array_diff_key(get_defined_vars(), ['__data' => 1, '__path' => 1]))->render(); ?>
        <?php endif; ?>
    <?php endif; ?>
</div><?php /**PATH /app/www/resources/views/entities/meta.blade.php ENDPATH**/ ?>