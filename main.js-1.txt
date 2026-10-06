import { createClient } from '@supabase/supabase-js'
import './style.css'

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || ''
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || ''
const supabase = SUPABASE_URL && SUPABASE_ANON_KEY ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null

const demoCategories=['Ciment','Tôles','Parpaings','Fer à béton','Peintures','Électricité','Plomberie','Outils','Quincaillerie']
const demoProducts=[
{id:'d1',name:'Ciment CPJ 45 (50 kg)',category:'Ciment',variant:'Sac de 50 kg',price:4750,unit:'sac',image:'https://images.unsplash.com/photo-1516214104703-d870798883c5?auto=format&fit=crop&w=800&q=80'},
{id:'d2',name:'Tôle ondulée galvanisée',category:'Tôles',variant:'Épaisseur 0,40 mm',price:2000,unit:'feuille',image:'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=800&q=80'},
{id:'d3',name:'Tôle bac aluminium',category:'Tôles',variant:'Épaisseur 0,50 mm',price:3300,unit:'mètre',image:'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=800&q=80'},
{id:'d4',name:'Peinture acrylique',category:'Peintures',variant:'15 L — plusieurs couleurs',price:12000,unit:'seau',image:'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&w=800&q=80'},
{id:'d5',name:'Ampoule LED 15W',category:'Électricité',variant:'E27',price:2500,unit:'pièce',image:'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=800&q=80'},
{id:'d6',name:'Fil électrique TH',category:'Électricité',variant:'1,5 / 2,5 / 4 mm²',price:16500,unit:'rouleau',image:'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=800&q=80'},
{id:'d7',name:'Tuyau PVC',category:'Plomberie',variant:'Ø 40 mm — 6 m',price:5500,unit:'barre',image:'https://images.unsplash.com/photo-1581094794329-c8112a89af12?auto=format&fit=crop&w=800&q=80'},
{id:'d8',name:'Perceuse + accessoires',category:'Outils',variant:'550 W — coffret complet',price:23000,unit:'coffret',image:'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=800&q=80'}]

let state={products:demoProducts,categories:demoCategories,query:'',category:'Toutes',maxPrice:100000,sort:'popular',favorites:new Set(),cart:JSON.parse(localStorage.getItem('rs_cart')||'[]'),isAdmin:false,catImg:{},user:null,paymentMethod:'wave'}
const app=document.querySelector('#root')
const money=n=>new Intl.NumberFormat('fr-FR').format(Number(n||0))+' FCFA'
const esc=s=>String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))
const stars=n=>'★★★★★'.split('').map((s,i)=>`<span class="star ${i<n?'on':''}">${s}</span>`).join('')

async function load(){
 if(supabase){
  const {data:{user}}=await supabase.auth.getUser(); state.user=user||null
  const {data:cats}=await supabase.from('categories').select('id,name,image_url').order('name')
  if(cats?.length){state.categories=cats.map(x=>x.name);cats.forEach(x=>{if(x.image_url)state.catImg[x.name]=x.image_url})}
  const {data:prods}=await supabase.from('products').select('*,categories(name)').eq('active',true).order('created_at',{ascending:false})
  if(prods?.length) state.products=prods.map(p=>({...p,category:p.categories?.name||'Quincaillerie',image:p.image_url||p.image||''}))
  if(user){const {data:a}=await supabase.from('admin_users').select('user_id').eq('user_id',user.id).maybeSingle();state.isAdmin=!!a;const {data:f}=await supabase.from('favorites').select('product_id').eq('user_id',user.id); if(f) state.favorites=new Set(f.map(x=>x.product_id))}
  supabase.auth.onAuthStateChange((_e,s)=>{state.user=s?.user||null;render()})
 }
 render()
}
function filtered(){
 let a=state.products.filter(p=>(state.category==='Toutes'||p.category===state.category)&&Number(p.price||0)<=state.maxPrice&&(`${p.name} ${p.variant||''} ${p.brand||''}`.toLowerCase().includes(state.query.toLowerCase())))
 if(state.sort==='priceAsc')a.sort((x,y)=>(+x.price)-(+y.price)); if(state.sort==='priceDesc')a.sort((x,y)=>(+y.price)-(+x.price)); if(state.sort==='name')a.sort((x,y)=>x.name.localeCompare(y.name)); return a
}
function addCart(p){if(oos(p))return toast('Produit en rupture de stock');const x=state.cart.find(i=>String(i.id)===String(p.id)); if(x)x.qty++; else state.cart.push({id:p.id,name:p.name,price:+p.price,qty:1});render();toast('Produit ajouté au panier')}
async function toggleFav(p){const on=!state.favorites.has(p.id);on?state.favorites.add(p.id):state.favorites.delete(p.id);if(supabase&&state.user&&!String(p.id).startsWith('d')){if(on)await supabase.from('favorites').upsert({user_id:state.user.id,product_id:p.id},{onConflict:'user_id,product_id'});else await supabase.from('favorites').delete().eq('user_id',state.user.id).eq('product_id',p.id)}document.querySelector('.hero')?render():favView()}
function toast(t){const x=document.createElement('div');x.className='toast';x.textContent=t;document.body.appendChild(x);setTimeout(()=>x.remove(),1800)}
const oos=p=>p.stock!=null&&Number(p.stock)<=0
const ICON={Ciment:'🧱','Tôles':'🏠',Parpaings:'🧱','Fer à béton':'🏗️',Peintures:'🎨','Électricité':'💡',Plomberie:'🚰',Outils:'🛠️',Quincaillerie:'🔩'}
const catTile=c=>state.catImg[c]?`<img src="${esc(state.catImg[c])}" alt=""/>`:`<i>${ICON[c]||'📦'}</i>`
function productCard(p){return `<article class="card"><div class="pic">${p.image?`<img src="${esc(p.image)}" onerror="this.style.display='none'"/>`:'📦'}<button class="heart ${state.favorites.has(p.id)?'on':''}" data-fav="${p.id}">${state.favorites.has(p.id)?'♥':'♡'}</button></div><div class="ct"><small>${esc(p.category||'Quincaillerie')}</small><h3>${esc(p.name)}</h3><p>${esc(p.variant||p.unit||'')}</p><b>${p.price?money(p.price):'Prix à définir'}</b>${p.unit?`<em>/ ${esc(p.unit)}</em>`:''}<div class="rating">${stars(Math.round(Number(p.rating||0)))}</div><button class="add" ${oos(p)?'disabled':''} data-add="${p.id}">${oos(p)?'Rupture de stock':'＋ Ajouter au panier'}</button><button class="details" data-details="${p.id}">Voir le produit</button></div></article>`}
function save(){try{localStorage.setItem('rs_cart',JSON.stringify(state.cart))}catch{}}
function render(){save()
 const list=filtered()
 app.innerHTML=`<header><div class="top"><div class="brand"><strong>ROBOAM <span>SERVICE</span> 🇨🇮</strong><small>Matériaux de construction • Quincaillerie • Bricolage</small></div><div class="hinfo"><div>🎧 Service client<br/>à votre écoute</div><div>🚚 Livraison rapide<br/>2 à 3 jours</div></div><button id="account">${state.user?'Compte':'Connexion'}</button></div><div class="search"><input id="search" value="${esc(state.query)}" placeholder="Rechercher ciment, tôles, outils..."/><span>⌕</span></div></header>
 <main><section class="hero"><div><label>ROBOAM SERVICE</label><h1>N°1 en Côte d'Ivoire</h1><h2>Votre partenaire de confiance en</h2><h3>Matériaux &amp; Quincaillerie</h3><button id="shop">Voir les produits</button><div class="badges"><span>🛡️ Produits de qualité<br/>100% fiables</span><span>🚚 Livraison rapide<br/>2 à 3 jours</span><span>🎧 Service client<br/>à votre écoute</span></div></div></section>
 <section><div class="secthead"><h2>Nos catégories Quincaillerie</h2><button id="allCats">Voir toutes</button></div><div class="cats"><button class="cat ${state.category==='Toutes'?'sel':''}" data-cat="Toutes"><i>🏠</i><span>Tout</span></button>${state.categories.map(c=>`<button class="cat ${state.category===c?'sel':''}" data-cat="${esc(c)}">${catTile(c)}<span>${esc(c)}</span></button>`).join('')}</div></section>
 <section><div class="secthead"><h2>🔥 Produits populaires</h2><span>${list.length} produit(s)</span></div><div class="filters"><select id="sort"><option value="popular">Pertinence</option><option value="priceAsc">Prix croissant</option><option value="priceDesc">Prix décroissant</option><option value="name">Nom A-Z</option></select><label>Prix max <b id="priceText">${money(state.maxPrice)}</b></label><input id="price" type="range" min="500" max="100000" step="500" value="${state.maxPrice}"></div><div class="grid">${list.length?list.map(productCard).join(''):'<div class="empty">Aucun produit trouvé.</div>'}</div></section>
 <section class="features"><div>🚚<b> Livraison rapide</b><small>2 à 3 jours partout en Côte d'Ivoire</small></div><div>🛡️<b> Paiement sécurisé</b><small>Wave / Orange Money / MTN</small></div><a class="wa" href="https://wa.me/2250712968887" target="_blank" rel="noopener">💬 Commandez sur WhatsApp<b>0712968887</b></a></section></main>
 <nav><button data-tab="Accueil">⌂<span>Accueil</span></button><button data-tab="Catégories">▦<span>Catégories</span></button><button data-tab="Panier">🛒<span>Panier ${state.cart.length?`(${state.cart.reduce((a,x)=>a+x.qty,0)})`:''}</span></button><button data-tab="Favoris">♡<span>Favoris</span></button><button data-tab="Compte">♙<span>Compte</span></button></nav><div class="flagbar">🇨🇮 <b>ROBOAM SERVICE</b> — N°1 en Côte d'Ivoire 🇨🇮</div>`
 bind()
}
function bind(){
 document.querySelector('#search').oninput=e=>{state.query=e.target.value;updateGrid()}
 document.querySelector('#sort').onchange=e=>{state.sort=e.target.value;render()}
 document.querySelector('#price').oninput=e=>{state.maxPrice=+e.target.value;document.querySelector('#priceText').textContent=money(state.maxPrice);updateGrid()}
 document.querySelector('#shop').onclick=()=>document.querySelector('.grid').scrollIntoView({behavior:'smooth'})
 document.querySelector('#allCats').onclick=()=>document.querySelector('.cats').scrollIntoView({behavior:'smooth'})
 document.querySelectorAll('[data-cat]').forEach(b=>b.onclick=()=>{state.category=b.dataset.cat;render()})
 document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>tab(b.dataset.tab))
 document.querySelector('#account').onclick=()=>tab('Compte')
 bindCards()
}
function updateGrid(){const g=document.querySelector('.grid');const list=filtered();g.innerHTML=list.length?list.map(productCard).join(''):'<div class="empty">Aucun produit trouvé.</div>';bindCards()}
function bindCards(){document.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>{const p=state.products.find(x=>String(x.id)===b.dataset.add);if(p)addCart(p)});document.querySelectorAll('[data-fav]').forEach(b=>b.onclick=()=>{const p=state.products.find(x=>String(x.id)===b.dataset.fav);if(p)toggleFav(p)});document.querySelectorAll('[data-details]').forEach(b=>b.onclick=()=>detailView(state.products.find(x=>String(x.id)===b.dataset.details)))}
function favView(){const l=state.products.filter(p=>state.favorites.has(p.id));shell('Mes favoris',`<div class="grid">${l.length?l.map(productCard).join(''):'<div class="empty">Aucun favori pour le moment. Touchez ♡ sur un produit pour l\'ajouter.</div>'}</div>`);bindCards()}
function categoryView(){shell('Catégories',`<div class="catgrid">${state.categories.map(c=>`<button data-c2="${esc(c)}">${catTile(c)}<span>${esc(c)}</span></button>`).join('')}</div>`);document.querySelectorAll('[data-c2]').forEach(b=>b.onclick=()=>{state.category=b.dataset.c2;render()})}
function tab(t){if(t==='Panier')return cartView();if(t==='Favoris')return favView();if(t==='Catégories')return categoryView();if(t==='Compte')return accountView()}
function shell(title,body){save();app.innerHTML=`<header><div class="top"><div><strong>ROBOAM</strong><span>SERVICE</span></div><button id="back">← Accueil</button></div></header><main class="page"><h1>${title}</h1>${body}</main><nav>${['Accueil','Catégories','Panier','Favoris','Compte'].map(x=>`<button data-tab="${x}">${x==='Accueil'?'⌂':x==='Catégories'?'▦':x==='Panier'?'🛒':x==='Favoris'?'♡':'♙'}<span>${x}</span></button>`).join('')}</nav><div class="flagbar">🇨🇮 <b>ROBOAM SERVICE</b> — N°1 en Côte d'Ivoire 🇨🇮</div>`;document.querySelector('#back').onclick=()=>render();document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>tab(b.dataset.tab))}
function cartView(){
 const total=state.cart.reduce((a,x)=>a+x.price*x.qty,0)
 const rows=state.cart.map((x,i)=>`<div class="cartrow"><b>${esc(x.name)}</b><span>${money(x.price*x.qty)}</span><div><button data-q="${i}" data-d="-1">−</button> ${x.qty} <button data-q="${i}" data-d="1">＋</button></div></div>`).join('')
 shell('Mon panier',state.cart.length?`<div class="cart">${rows}<h2>Total : ${money(total)}</h2><button class="primary" id="checkout">Passer au paiement</button></div>`:'<div class="empty">Votre panier est vide.</div>')
 document.querySelectorAll('[data-q]').forEach(b=>b.onclick=()=>{const i=+b.dataset.q;state.cart[i].qty+=+b.dataset.d;if(state.cart[i].qty<=0)state.cart.splice(i,1);cartView()})
 document.querySelector('#checkout')?.addEventListener('click',checkoutView)
}
function checkoutView(){
 const total=state.cart.reduce((a,x)=>a+x.price*x.qty,0)
 shell('Paiement sécurisé',`<div class="panel payment-panel">
 <h2>${money(total)}</h2><p class="muted">Choisissez votre moyen de paiement. Le paiement réel sera confirmé par le prestataire avant validation de la commande.</p>
 <div class="pay-options">
  <button class="pay ${state.paymentMethod==='wave'?'sel':''}" data-pay="wave">🟣 <b>Wave</b><small>Paiement en ligne</small></button>
  <button class="pay ${state.paymentMethod==='orange'?'sel':''}" data-pay="orange">🟠 <b>Orange Money</b><small>Paiement mobile</small></button>
  <button class="pay ${state.paymentMethod==='mtn'?'sel':''}" data-pay="mtn">🟡 <b>MTN Mobile Money</b><small>MoMo</small></button>
  <button class="pay ${state.paymentMethod==='cash'?'sel':''}" data-pay="cash">🚚 <b>Paiement à la livraison</b><small>Selon disponibilité</small></button>
 </div>
 <input id="phone" placeholder="Téléphone du payeur (ex. 07...)" inputmode="tel"/>
 <input id="commune" placeholder="Commune de livraison"/>
 <input id="quartier" placeholder="Quartier / repère"/>
 <button class="primary" id="payNow">${state.paymentMethod==='cash'?'Confirmer la commande':'Continuer vers le paiement'}</button>
 <p id="paymentMsg" class="muted"></p>
 </div>`)
 document.querySelectorAll('[data-pay]').forEach(b=>b.onclick=()=>{state.paymentMethod=b.dataset.pay;checkoutView()})
 document.querySelector('#payNow').onclick=()=>startPayment()
}
const STATUS=['reçue','confirmée','préparation','en livraison','livrée']
const PROV={wave:'wave',orange:'orange_money',mtn:'mtn_momo',cash:'cash'}
async function startPayment(){
 const msg=document.querySelector('#paymentMsg'),phone=document.querySelector('#phone').value.trim(),commune=document.querySelector('#commune').value.trim(),quartier=document.querySelector('#quartier').value.trim()
 if(!phone||!commune){msg.textContent='Indiquez le téléphone et la commune de livraison.';return}
 if(!supabase||!state.user){msg.textContent='Connectez-vous (onglet Compte) pour passer commande.';return}
 if(state.cart.some(x=>String(x.id).startsWith('d'))){msg.textContent='Le panier contient des produits de démonstration. Videz-le et ajoutez des produits du catalogue.';return}
 const m=state.paymentMethod,cash=m==='cash'
 const {error}=await supabase.rpc('create_order',{p_items:state.cart.map(x=>({id:x.id,qty:x.qty})),p_phone:phone,p_method:m,p_commune:commune,p_quartier:quartier})
 if(error){msg.textContent=error.message;return}
 state.cart=[];save();toast(cash?'Commande enregistrée':'Commande créée — paiement en attente');ordersView()
}
async function ordersView(){
 if(!supabase||!state.user)return accountView()
 const {data=[]}=await supabase.from('orders').select('*,order_items(product_name,quantity)').eq('user_id',state.user.id).order('created_at',{ascending:false})
 shell('Mes commandes',data?.length?data.map(o=>{const i=Math.max(0,STATUS.indexOf(o.status));return `<div class="panel"><b>Commande #${o.id}</b> — ${money(o.total)}<p class="muted">${esc((o.order_items||[]).map(x=>x.quantity+'× '+x.product_name).join(', '))}</p><p>${STATUS.map((s,k)=>`<span style="opacity:${k<=i?1:.35}">${k<=i?'●':'○'} ${s}</span>`).join(' → ')}</p><small>Paiement : ${esc(o.payment_status)} (${esc(o.payment_provider||'')})</small></div>`}).join(''):'<div class="empty">Aucune commande.</div>')
}
async function adminView(){
 if(!state.isAdmin)return toast('Accès réservé aux administrateurs.')
 const {data:orders}=await supabase.from('orders').select('*,order_items(product_name,quantity)').order('created_at',{ascending:false})
 const {data:cats}=await supabase.from('categories').select('id,name').order('name')
 const {data:prods}=await supabase.from('products').select('id,name,price,stock,active').order('name')
 const opt=(list,v)=>list.map(x=>`<option ${x===v?'selected':''}>${x}</option>`).join('')
 shell('Administration',`<div class="panel"><h3>Ajouter un produit</h3><input id="pn" placeholder="Nom"/><input id="pp" type="number" placeholder="Prix FCFA"/><input id="ps" type="number" placeholder="Stock"/><input id="pi" placeholder="URL de la photo"/><select id="pc">${(cats||[]).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('')}</select><button class="primary" id="pAdd">Enregistrer</button></div><h3>Produits (${(prods||[]).length})</h3>${(prods||[]).map(p=>`<div class="panel"><b>${esc(p.name)}</b>${p.active?'':' (masqué)'}<input data-pp="${p.id}" type="number" value="${p.price}"/><input data-pst="${p.id}" type="number" value="${p.stock}"/><div class="actions"><button data-sv="${p.id}">Enregistrer</button><button data-tg="${p.id}" data-a="${p.active}">${p.active?'Masquer':'Afficher'}</button><button data-dl="${p.id}">Supprimer</button></div></div>`).join('')}<h3>Commandes (${(orders||[]).length})</h3>${(orders||[]).map(o=>`<div class="panel"><b>#${o.id}</b> ${money(o.total)} — ${esc(o.phone||'')} — ${esc(o.delivery_commune||'')}<p class="muted">${esc((o.order_items||[]).map(x=>x.quantity+'× '+x.product_name).join(', '))}</p><select data-st="${o.id}">${opt(STATUS,o.status)}</select> <select data-ps="${o.id}">${opt(['pending','paid','failed','cancelled','cash_on_delivery'],o.payment_status)}</select></div>`).join('')}`)
 document.querySelectorAll('[data-st]').forEach(s=>s.onchange=async()=>{const {error}=await supabase.from('orders').update({status:s.value}).eq('id',s.dataset.st);toast(error?error.message:'Statut mis à jour')})
 document.querySelectorAll('[data-ps]').forEach(s=>s.onchange=async()=>{const {error}=await supabase.from('orders').update({payment_status:s.value,paid_at:s.value==='paid'?new Date().toISOString():null}).eq('id',s.dataset.ps);toast(error?error.message:'Paiement mis à jour')})
 document.querySelectorAll('[data-sv]').forEach(b=>b.onclick=async()=>{const i=b.dataset.sv,{error}=await supabase.from('products').update({price:+document.querySelector(`[data-pp="${i}"]`).value,stock:+document.querySelector(`[data-pst="${i}"]`).value}).eq('id',i);toast(error?error.message:'Produit mis à jour')})
 document.querySelectorAll('[data-tg]').forEach(b=>b.onclick=async()=>{const {error}=await supabase.from('products').update({active:b.dataset.a!=='true'}).eq('id',b.dataset.tg);toast(error?error.message:'Visibilité modifiée');if(!error){await load();adminView()}})
 document.querySelectorAll('[data-dl]').forEach(b=>b.onclick=async()=>{if(!confirm('Supprimer ce produit ?'))return;const {error}=await supabase.from('products').delete().eq('id',b.dataset.dl);toast(error?'Suppression impossible (déjà commandé ?) : utilisez Masquer':'Produit supprimé');if(!error){await load();adminView()}})
 document.querySelector('#pAdd').onclick=async()=>{const {error}=await supabase.from('products').insert({name:pn.value,price:+pp.value,stock:+ps.value||0,image_url:pi.value||null,category_id:+pc.value});toast(error?error.message:'Produit ajouté');if(!error)load()}
}
function accountView(){shell('Mon compte',state.user?`<div class="panel"><p>Connecté avec : <b>${esc(state.user.email)}</b></p><div class=\"actions\"><button id=\"myOrders\">📦 Mes commandes</button>${state.isAdmin?'<button id=\"adminBtn\">⚙️ Administration</button>':''}</div><button class="primary" id="signout">Se déconnecter</button></div>`:`<div class="panel"><p>Connecte ton compte pour synchroniser favoris et avis.</p><input id="email" placeholder="Email"/><input id="password" type="password" placeholder="Mot de passe"/><div class="actions"><button class="primary" id="login">Se connecter</button><button id="signup">Créer un compte</button></div><small id="msg"></small></div>`);document.querySelector('#myOrders')?.addEventListener('click',ordersView);document.querySelector('#adminBtn')?.addEventListener('click',adminView);document.querySelector('#login')?.addEventListener('click',authLogin);document.querySelector('#signup')?.addEventListener('click',authSignup);document.querySelector('#signout')?.addEventListener('click',async()=>{await supabase?.auth.signOut();state.user=null;render()})}
async function authLogin(){if(!supabase)return toast('Configure le fichier .env puis recharge.');const email=document.querySelector('#email').value,password=document.querySelector('#password').value;const {error}=await supabase.auth.signInWithPassword({email,password});if(error)document.querySelector('#msg').textContent=error.message;else{await load();toast('Connexion réussie')}}
async function authSignup(){if(!supabase)return toast('Configure le fichier .env puis recharge.');const email=document.querySelector('#email').value,password=document.querySelector('#password').value;const {error}=await supabase.auth.signUp({email,password});if(error)document.querySelector('#msg').textContent=error.message;else document.querySelector('#msg').textContent='Compte créé. Vérifie ton email si demandé.'}
async function detailView(p){if(!p)return;let reviews=[];if(supabase&&!String(p.id).startsWith('d')){const {data}=await supabase.from('product_reviews').select('rating,comment,created_at').eq('product_id',p.id).order('created_at',{ascending:false});reviews=data||[]}const reviewHtml=reviews.length?reviews.map(r=>`<div class="review"><div>${stars(r.rating)}</div><p>${esc(r.comment||'')}</p></div>`).join(''):'<p class="muted">Aucun avis pour le moment.</p>';shell(p.name,`<div class="detail"><img src="${esc(p.image||'')}" onerror="this.style.display='none'"/><div><p>${esc(p.variant||p.unit||'')}</p><h2>${p.price?money(p.price):'Prix à définir'}</h2><button class="primary" id="detailAdd">Ajouter au panier</button></div><hr><h3>Avis clients</h3><div>${reviewHtml}</div>${supabase?`<div class="panel"><h3>Votre avis</h3><select id="rating"><option value="5">★★★★★</option><option value="4">★★★★☆</option><option value="3">★★★☆☆</option><option value="2">★★☆☆☆</option><option value="1">★☆☆☆☆</option></select><textarea id="comment" placeholder="Votre commentaire"></textarea><button class="primary" id="reviewSend">Publier</button></div>`:''}</div>`);document.querySelector('#detailAdd').onclick=()=>addCart(p);document.querySelector('#reviewSend')?.addEventListener('click',()=>sendReview(p))}
async function sendReview(p){if(!state.user)return toast('Connectez-vous pour publier un avis.');const rating=+document.querySelector('#rating').value,comment=document.querySelector('#comment').value.trim();const {error}=await supabase.from('product_reviews').upsert({product_id:p.id,user_id:state.user.id,rating,comment},{onConflict:'product_id,user_id'});if(error)toast(error.message);else{toast('Avis enregistré');detailView(p)}}
load()
