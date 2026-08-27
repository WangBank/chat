const MAX_AVATAR_BYTES = 100 * 1024;

function loadImageElement(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    const objectUrl = URL.createObjectURL(file);
    image.onload = () => {
      URL.revokeObjectURL(objectUrl);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error('图片无法读取'));
    };
    image.src = objectUrl;
  });
}

function canvasToJpeg(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) {
        resolve(blob);
      } else {
        reject(new Error('头像裁剪失败'));
      }
    }, 'image/jpeg', quality);
  });
}

/** Crop and compress oversized avatars to a square JPEG no larger than 100 KiB. */
export async function cropAvatarIfNeeded(file: File): Promise<File> {
  if (file.size <= MAX_AVATAR_BYTES) return file;

  const image = await loadImageElement(file);
  const sourceSize = Math.min(image.naturalWidth, image.naturalHeight);
  if (!sourceSize) throw new Error('图片尺寸无效');

  const sourceX = Math.floor((image.naturalWidth - sourceSize) / 2);
  const sourceY = Math.floor((image.naturalHeight - sourceSize) / 2);
  const canvas = document.createElement('canvas');
  const context = canvas.getContext('2d');
  if (!context) throw new Error('浏览器不支持头像裁剪');

  let size = Math.min(512, sourceSize);
  let lastBlob: Blob | undefined;
  while (size >= 64) {
    canvas.width = size;
    canvas.height = size;
    context.drawImage(image, sourceX, sourceY, sourceSize, sourceSize, 0, 0, size, size);

    for (const quality of [0.85, 0.7, 0.55, 0.4, 0.25]) {
      const blob = await canvasToJpeg(canvas, quality);
      lastBlob = blob;
      if (blob.size <= MAX_AVATAR_BYTES) {
        const filename = `${file.name.replace(/\.[^.]+$/, '') || 'avatar'}.jpg`;
        return new File([blob], filename, { type: 'image/jpeg' });
      }
    }
    size = Math.floor(size * 0.75);
  }

  if (!lastBlob || lastBlob.size > MAX_AVATAR_BYTES) {
    throw new Error('头像无法裁剪到 100KB 以内');
  }
  const filename = `${file.name.replace(/\.[^.]+$/, '') || 'avatar'}.jpg`;
  return new File([lastBlob], filename, { type: 'image/jpeg' });
}
