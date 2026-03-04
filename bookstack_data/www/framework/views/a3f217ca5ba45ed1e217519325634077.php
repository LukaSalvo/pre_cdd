<a href="<?php echo e($entity->getUrl()); ?>" class="grid-card"
   data-entity-type="<?php echo e($entity->getType()); ?>" data-entity-id="<?php echo e($entity->id); ?>">
    <div class="bg-<?php echo e($entity->getType()); ?> featured-image-container-wrap">
        <div class="featured-image-container" <?php if($entity->coverInfo()->exists()): ?> style="background-image: url('<?php echo e($entity->coverInfo()->getUrl()); ?>')"<?php endif; ?>>
        </div>
        <?php echo (new \BookStack\Util\SvgIcon($entity->getType()))->toHtml(); ?>
    </div>
    <div class="grid-card-content">
        <h2 class="text-limit-lines-2"><?php echo e($entity->name); ?></h2>
        <p class="text-muted"><?php echo e($entity->getExcerpt(130)); ?></p>
    </div>
    <div class="grid-card-footer text-muted ">
        <p><?php echo (new \BookStack\Util\SvgIcon('star'))->toHtml(); ?><span title="<?php echo e($dates->absolute($entity->created_at)); ?>"><?php echo e(trans('entities.meta_created', ['timeLength' => $dates->relative($entity->created_at)])); ?></span></p>
        <p><?php echo (new \BookStack\Util\SvgIcon('edit'))->toHtml(); ?><span title="<?php echo e($dates->absolute($entity->updated_at)); ?>"><?php echo e(trans('entities.meta_updated', ['timeLength' => $dates->relative($entity->updated_at)])); ?></span></p>
    </div>
</a><?php /**PATH /app/www/resources/views/entities/grid-item.blade.php ENDPATH**/ ?>