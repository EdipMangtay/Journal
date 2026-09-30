import sharp from 'sharp';
import decodeHEIC from 'heic-decode';
import { randomUUID } from 'node:crypto';
import path from 'node:path';

const maxBytes=30000000, maxPixels=100000000;
export async function imagePipeline(bytes){
  if(!bytes.length||bytes.length>maxBytes)throw new Error('Images must be smaller than 30 MB.');
  const pipeline=sharp(bytes,{limitInputPixels:maxPixels}),meta=await pipeline.metadata();
  if(!meta.width||!meta.height||meta.width*meta.height>maxPixels)throw new Error('Choose a supported image under 100 megapixels.');
  if(!['png','jpeg','webp','tiff','heif'].includes(meta.format))throw new Error('Choose PNG, JPEG, HEIC, TIFF or WebP images.');
  if(meta.format==='heif'){
    const decoded=await decodeHEIC({buffer:bytes});
    return sharp(decoded.data,{raw:{width:decoded.width,height:decoded.height,channels:4},limitInputPixels:maxPixels});
  }
  return pipeline.rotate();
}
export async function loadImage(name,bytes){
  const pipeline=await imagePipeline(bytes),thumbnail=await pipeline.resize({width:600,height:600,fit:'inside',withoutEnlargement:true}).jpeg({quality:80}).toBuffer();
  return{id:randomUUID(),name:path.basename(String(name)),category:'Entry',imageData:bytes.toString('base64'),thumbnailData:thumbnail.toString('base64'),annotations:[]};
}
export async function validateImages(backup){
  for(const shot of [...backup.screenshots.map(s=>s.screenshot),...backup.setups.flatMap(s=>s.images)]){
    for(const key of ['imageData','thumbnailData'])await imagePipeline(Buffer.from(shot[key],'base64'));
  }
  return backup;
}
