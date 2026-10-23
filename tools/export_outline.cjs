/* Original vector touch artwork; npm install sharp only to regenerate PNGs. */
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.join(__dirname, '../assets/ios-outline');
const circle = '<circle cx="32" cy="32" r="28"/>';
const pill = '<rect x="3" y="3" width="82" height="42" rx="21"/>';
const small = '<rect x="3" y="3" width="58" height="38" rx="19"/>';
const drawings = {
  dpad: [128,128, '<path d="M50 5H78Q85 5 85 12V43H116Q123 43 123 50V78Q123 85 116 85H85V116Q85 123 78 123H50Q43 123 43 116V85H12Q5 85 5 78V50Q5 43 12 43H43V12Q43 5 50 5Z"/><path d="M57 26L64 19L71 26M102 57L109 64L102 71M57 102L64 109L71 102M26 57L19 64L26 71"/><circle cx="64" cy="64" r="5"/>'],
  a: [64,64, circle+'<path d="M23 42L32 21L41 42M27 34H37"/>'],
  b: [64,64, circle+'<path d="M25 22V42H33C44 42 44 31 33 31H25M25 22H33C43 22 43 31 33 31"/>'],
  l: [88,48, pill+'<path d="M39 15V33H51"/>'],
  r: [88,48, pill+'<path d="M38 33V15H45C55 15 55 25 45 25H38M45 25L53 33"/>'],
  select: [64,44, small+'<rect x="28" y="17" width="12" height="12" rx="2"/><path d="M24 25H22Q20 25 20 23V13Q20 11 22 11H32Q34 11 34 13"/>'],
  start: [64,44, small+'<path d="M28 13L41 22L28 31Z"/>'],
  menu: [44,44, '<circle cx="22" cy="22" r="18"/><path d="M18 16V28M26 16V28"/>']
};
async function main() {
  fs.mkdirSync(path.join(root,'svg'),{recursive:true});
  fs.mkdirSync(path.join(root,'png'),{recursive:true});
  const icons={};
  for(const [name,[w,h,body]] of Object.entries(drawings)) {
    const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body}</svg>\n`;
    fs.writeFileSync(path.join(root,'svg',name+'.svg'),svg);
    await sharp(Buffer.from(svg)).resize(w*3,h*3).png().toFile(path.join(root,'png',name+'@3x.png'));
    icons[name]={svg:`svg/${name}.svg`,png:`png/${name}@3x.png`,width:w,height:h,scale:3};
  }
  fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify({version:1,color:'#FFFFFF',strokeWidth:2,background:'transparent',icons},null,2)+'\n');
  console.log('Exported 8 white outline SVGs and transparent PNGs @3x.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
