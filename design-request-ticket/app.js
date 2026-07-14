// ISPOR / PEOR — Design Request Ticket
// Multi-step bilingual (EN/AR) request form. Submits to the Apps Script
// backend in apps-script/Code.gs (URL configured in config.js).
(function () {
  'use strict';

  const TEAMS = [
    { key: 'Scientific Affairs Team', ar: 'فريق الشؤون العلمية' },
    { key: 'Media Team', ar: 'فريق الإعلام' },
    { key: 'Event Management Team', ar: 'فريق إدارة الفعاليات' },
    { key: 'Competition Team', ar: 'فريق المسابقات' },
    { key: 'Sponsorship Team', ar: 'فريق الرعاية' },
    { key: 'Research Affairs Team', ar: 'فريق الشؤون البحثية' },
    { key: 'Public Relation Team', ar: 'فريق العلاقات العامة' },
    { key: 'Logistics Team', ar: 'فريق اللوجستيات' },
    { key: 'Organizing Committee', ar: 'اللجنة المنظمة' },
  ];

  const DESIGN_TYPES = [
    { key: 'Social Post', ar: 'منشور اجتماعي' },
    { key: 'Banner', ar: 'بانر' },
    { key: 'Presentation', ar: 'عرض تقديمي' },
    { key: 'Certificate', ar: 'شهادة' },
    { key: 'Logo', ar: 'شعار' },
    { key: 'Other', ar: 'أخرى' },
  ];

  const FILE_FORMATS = ['PNG', 'PDF', 'PPTX'];

  const LANGUAGES = [
    { key: 'Arabic', ar: 'العربية' },
    { key: 'English', ar: 'الإنجليزية' },
    { key: 'Both', ar: 'كلاهما' },
  ];

  const PRIORITIES = [
    { key: 'Normal', ar: 'عادي', color: '#8a93a6' },
    { key: 'Urgent', ar: 'عاجل', color: '#d97706' },
    { key: 'Critical', ar: 'حرج', color: '#dc2626' },
  ];

  const SIZES = [
    ['', 'Select size / اختر المقاس'],
    ['1:1', '1:1 (Square)'],
    ['4:5', '4:5 (Portrait)'],
    ['9:16', '9:16 (Story)'],
    ['A4', 'A4'],
    ['A5', 'A5'],
    ['Custom', 'Custom / مخصص'],
  ];

  const STEP_NAMES = [
    { en: 'Requester', ar: 'مقدّم الطلب' },
    { en: 'Basics', ar: 'الأساسيات' },
    { en: 'Specs', ar: 'المواصفات' },
    { en: 'Deadlines', ar: 'المواعيد' },
    { en: 'Assets', ar: 'المرفقات' },
  ];

  const CHECK_ICON_SVG =
    '<svg width="30" height="30" viewBox="0 0 24 24" fill="none"><path d="M4 12.5l5 5L20 7" stroke="#6d3fb0" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  const UPLOAD_ICON_SVG =
    '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><path d="M12 4v11m0-11l-4 4m4-4l4 4M5 17v2a2 2 0 002 2h10a2 2 0 002-2v-2" stroke="#6d3fb0" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  function emptyData() {
    return {
      fullName: '', team: '', contact: '',
      title: '', designTypes: [], otherDesignType: '', language: '', brief: '', priority: '',
      size: '', customSize: '', fileFormats: [],
      draftDate: '', finalDate: '', publishDate: '',
      copyText: '', files: [], links: '', colorNotes: '', avoid: '',
    };
  }

  const state = {
    step: 0,
    submitted: false,
    submitting: false,
    error: '',
    ticketId: '',
    data: emptyData(),
  };

  const root = document.getElementById('app');

  function el(tag, props, children) {
    const node = document.createElement(tag);
    if (props) {
      Object.keys(props).forEach((k) => {
        const v = props[k];
        if (k === 'class') node.className = v;
        else if (k === 'style') Object.assign(node.style, v);
        else if (k.indexOf('on') === 0 && typeof v === 'function') node.addEventListener(k.slice(2).toLowerCase(), v);
        else if (v !== undefined && v !== null && v !== false) node.setAttribute(k, v === true ? '' : v);
      });
    }
    (children || []).forEach((c) => {
      if (c === null || c === undefined) return;
      node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    });
    return node;
  }

  function svgFromString(svgStr) {
    const template = document.createElement('template');
    template.innerHTML = svgStr.trim();
    return template.content.firstChild;
  }

  function fieldLabel(en, ar, required) {
    return el('label', { class: 'field-label' }, [
      el('span', null, [en + ' ', el('span', { dir: 'rtl', class: 'ar' }, ['/ ' + ar])]),
      el('span', { class: 'badge ' + (required ? 'required' : 'optional') }, [required ? 'Required' : 'Optional']),
    ]);
  }

  function canProceed(step, data) {
    if (step === 0) return !!(data.fullName && data.team && data.contact);
    if (step === 1) return !!(data.title && data.designTypes.length && data.language && data.priority);
    if (step === 2) return !!(data.size && (data.size !== 'Custom' || data.customSize) && data.fileFormats.length);
    if (step === 3) return !!data.finalDate;
    return true;
  }

  function set(key, val) {
    state.data[key] = val;
    render();
  }

  function toggle(key, val) {
    const arr = state.data[key];
    state.data[key] = arr.includes(val) ? arr.filter((v) => v !== val) : arr.concat([val]);
    render();
  }

  function handleFiles(e) {
    const files = Array.from(e.target.files || []);
    if (files.length) state.data.files = state.data.files.concat(files);
    render();
  }

  function removeFile(idx) {
    state.data.files = state.data.files.filter((_, i) => i !== idx);
    render();
  }

  function renderProgress() {
    const row = el('div', { class: 'progress' });
    STEP_NAMES.forEach((s, i) => {
      const active = i === state.step;
      const done = i < state.step;
      let circleBg = '#fff', circleColor = 'var(--ink-3)', circleBorder = 'var(--rule)', textColor = 'var(--ink-3)';
      if (active) {
        circleBg = 'var(--blue-1)'; circleColor = '#fff'; circleBorder = 'var(--blue-1)'; textColor = 'var(--blue-3)';
      } else if (done) {
        circleBg = '#fff'; circleColor = 'var(--blue-1)'; circleBorder = 'var(--blue-1)'; textColor = 'var(--ink-2)';
      }
      const btn = el('button', { class: 'step', type: 'button', onClick: () => { state.step = i; render(); } });
      if (i > 0) {
        btn.appendChild(el('div', { class: 'line', style: { background: i <= state.step ? 'var(--blue-1)' : 'var(--rule)' } }));
      }
      btn.appendChild(el('div', { class: 'circle', style: { background: circleBg, color: circleColor, borderColor: circleBorder } }, [String.fromCharCode(65 + i)]));
      btn.appendChild(el('div', { class: 'name-en', style: { color: textColor } }, [s.en]));
      btn.appendChild(el('div', { class: 'name-ar', style: { color: textColor } }, [s.ar]));
      row.appendChild(btn);
    });
    return row;
  }

  function sectionTitle(en, ar) {
    return el('div', { class: 'section-title' }, [
      el('div', { class: 'en' }, [en]),
      el('div', { class: 'ar', dir: 'rtl' }, [ar]),
    ]);
  }

  function renderStep0() {
    const wrap = el('div');
    wrap.appendChild(sectionTitle('Requester Info', 'معلومات مقدّم الطلب'));
    const group = el('div', { class: 'field-group' });

    const nameField = el('div', { class: 'field' });
    nameField.appendChild(fieldLabel('Full name', 'الاسم الكامل', true));
    const nameInput = el('input', { type: 'text', placeholder: 'e.g. Sara Al-Mansoori' });
    nameInput.value = state.data.fullName;
    nameInput.addEventListener('input', (e) => set('fullName', e.target.value));
    nameField.appendChild(nameInput);
    group.appendChild(nameField);

    const teamField = el('div', { class: 'field' });
    teamField.appendChild(fieldLabel('Team', 'الفريق', true));
    const teamSelect = el('select');
    teamSelect.appendChild(el('option', { value: '' }, ['Select team / اختر الفريق']));
    TEAMS.forEach((t) => teamSelect.appendChild(el('option', { value: t.key }, [t.key + ' / ' + t.ar])));
    teamSelect.value = state.data.team;
    teamSelect.addEventListener('change', (e) => set('team', e.target.value));
    teamField.appendChild(teamSelect);
    group.appendChild(teamField);

    const contactField = el('div', { class: 'field' });
    contactField.appendChild(fieldLabel('Contact (WhatsApp or email)', 'جهة التواصل', true));
    const contactInput = el('input', { type: 'text', placeholder: '+971 5X XXX XXXX or name@email.com' });
    contactInput.value = state.data.contact;
    contactInput.addEventListener('input', (e) => set('contact', e.target.value));
    contactField.appendChild(contactInput);
    group.appendChild(contactField);

    wrap.appendChild(group);
    return wrap;
  }

  function renderStep1() {
    const wrap = el('div');
    wrap.appendChild(sectionTitle('Request Basics', 'تفاصيل الطلب'));
    const group = el('div', { class: 'field-group spaced' });

    const titleField = el('div', { class: 'field' });
    titleField.appendChild(fieldLabel('Request title', 'عنوان الطلب', true));
    const titleInput = el('input', { type: 'text', placeholder: 'e.g. Ramadan Iftar Event Poster' });
    titleInput.value = state.data.title;
    titleInput.addEventListener('input', (e) => set('title', e.target.value));
    titleField.appendChild(titleInput);
    group.appendChild(titleField);

    const typeField = el('div', { class: 'field' });
    typeField.appendChild(fieldLabel('Design type', 'نوع التصميم', true));
    const chipRow = el('div', { class: 'chip-row' });
    DESIGN_TYPES.forEach((t) => {
      const selected = state.data.designTypes.includes(t.key);
      const chip = el('button', { class: 'chip' + (selected ? ' selected' : ''), type: 'button', onClick: () => toggle('designTypes', t.key) });
      chip.appendChild(document.createTextNode(t.key + ' '));
      chip.appendChild(el('span', { class: 'ar', dir: 'rtl' }, ['/ ' + t.ar]));
      chipRow.appendChild(chip);
    });
    typeField.appendChild(chipRow);
    if (state.data.designTypes.includes('Other')) {
      const otherInput = el('input', { type: 'text', placeholder: 'Please specify the design type... / يرجى تحديد نوع التصميم', style: { marginTop: '12px' } });
      otherInput.value = state.data.otherDesignType;
      otherInput.addEventListener('input', (e) => set('otherDesignType', e.target.value));
      typeField.appendChild(otherInput);
    }
    group.appendChild(typeField);

    const langField = el('div', { class: 'field' });
    langField.appendChild(fieldLabel('Language', 'اللغة', true));
    const langRow = el('div', { class: 'pill-row' });
    LANGUAGES.forEach((l) => {
      const selected = state.data.language === l.key;
      const pill = el('button', { class: 'pill' + (selected ? ' selected' : ''), type: 'button', onClick: () => set('language', l.key) });
      const dot = el('span', { class: 'radio-dot' });
      if (selected) dot.appendChild(el('span', { class: 'dot' }));
      pill.appendChild(dot);
      pill.appendChild(document.createTextNode(l.key + ' '));
      pill.appendChild(el('span', { dir: 'rtl' }, ['/ ' + l.ar]));
      langRow.appendChild(pill);
    });
    langField.appendChild(langRow);
    group.appendChild(langField);

    const briefField = el('div', { class: 'field' });
    briefField.appendChild(fieldLabel('Brief', 'الوصف', false));
    briefField.appendChild(el('div', { class: 'hint' }, ['What is the design for? What message should it convey?']));
    const briefTextarea = el('textarea', { rows: 4, placeholder: 'Describe the purpose and key message...' });
    briefTextarea.value = state.data.brief;
    briefTextarea.addEventListener('input', (e) => set('brief', e.target.value));
    briefField.appendChild(briefTextarea);
    group.appendChild(briefField);

    const prioField = el('div', { class: 'field' });
    prioField.appendChild(fieldLabel('Priority', 'الأولوية', true));
    const prioRow = el('div', { class: 'pill-row' });
    PRIORITIES.forEach((p) => {
      const selected = state.data.priority === p.key;
      const pill = el('button', { class: 'priority-pill' + (selected ? ' selected' : ''), type: 'button', onClick: () => set('priority', p.key) });
      pill.appendChild(el('span', { class: 'dot', style: { background: p.color } }));
      pill.appendChild(document.createTextNode(p.key + ' '));
      pill.appendChild(el('span', { dir: 'rtl' }, ['/ ' + p.ar]));
      prioRow.appendChild(pill);
    });
    prioField.appendChild(prioRow);
    group.appendChild(prioField);

    wrap.appendChild(group);
    return wrap;
  }

  function renderStep2() {
    const wrap = el('div');
    wrap.appendChild(sectionTitle('Dimensions & Specs', 'المقاسات والمواصفات'));
    const group = el('div', { class: 'field-group spaced' });

    const sizeField = el('div', { class: 'field' });
    sizeField.appendChild(fieldLabel('Size', 'المقاس', true));
    const sizeSelect = el('select');
    SIZES.forEach(([val, label]) => sizeSelect.appendChild(el('option', { value: val }, [label])));
    sizeSelect.value = state.data.size;
    sizeSelect.addEventListener('change', (e) => set('size', e.target.value));
    sizeField.appendChild(sizeSelect);
    if (state.data.size === 'Custom') {
      const customInput = el('input', { type: 'text', placeholder: 'e.g. 1200 x 628 px', style: { marginTop: '10px' } });
      customInput.value = state.data.customSize;
      customInput.addEventListener('input', (e) => set('customSize', e.target.value));
      sizeField.appendChild(customInput);
    }
    group.appendChild(sizeField);

    const formatField = el('div', { class: 'field' });
    formatField.appendChild(fieldLabel('File format needed', 'صيغة الملف', true));
    const formatRow = el('div', { class: 'chip-row' });
    FILE_FORMATS.forEach((f) => {
      const selected = state.data.fileFormats.includes(f);
      formatRow.appendChild(el('button', { class: 'format-chip' + (selected ? ' selected' : ''), type: 'button', onClick: () => toggle('fileFormats', f) }, [f]));
    });
    formatField.appendChild(formatRow);
    group.appendChild(formatField);

    wrap.appendChild(group);
    return wrap;
  }

  function renderStep3() {
    const wrap = el('div');
    wrap.appendChild(sectionTitle('Deadlines', 'المواعيد النهائية'));
    const group = el('div', { class: 'field-group' });

    const draft = el('div', { class: 'field' });
    draft.appendChild(fieldLabel('First draft needed by', 'موعد المسودة الأولى', false));
    const draftInput = el('input', { type: 'date' });
    draftInput.value = state.data.draftDate;
    draftInput.addEventListener('change', (e) => set('draftDate', e.target.value));
    draft.appendChild(draftInput);
    group.appendChild(draft);

    const finalField = el('div', { class: 'field' });
    finalField.appendChild(fieldLabel('Final file needed by', 'موعد الملف النهائي', true));
    const finalInput = el('input', { type: 'date' });
    finalInput.value = state.data.finalDate;
    finalInput.addEventListener('change', (e) => set('finalDate', e.target.value));
    finalField.appendChild(finalInput);
    group.appendChild(finalField);

    const publish = el('div', { class: 'field' });
    publish.appendChild(fieldLabel('Publish / event date', 'تاريخ النشر أو الفعالية', false));
    const publishInput = el('input', { type: 'date' });
    publishInput.value = state.data.publishDate;
    publishInput.addEventListener('change', (e) => set('publishDate', e.target.value));
    publish.appendChild(publishInput);
    group.appendChild(publish);

    wrap.appendChild(group);
    return wrap;
  }

  function renderStep4() {
    const wrap = el('div');
    wrap.appendChild(sectionTitle('Content & Assets', 'المحتوى والمرفقات'));
    const group = el('div', { class: 'field-group' });

    const copyField = el('div', { class: 'field' });
    copyField.appendChild(fieldLabel('Text / copy', 'النص المطلوب', true));
    copyField.appendChild(el('div', { class: 'hint' }, ['Paste exact titles, dates, taglines to include']));
    const copyTextarea = el('textarea', { rows: 4, placeholder: 'Paste exact copy here...' });
    copyTextarea.value = state.data.copyText;
    copyTextarea.addEventListener('input', (e) => set('copyText', e.target.value));
    copyField.appendChild(copyTextarea);
    group.appendChild(copyField);

    const filesField = el('div', { class: 'field' });
    filesField.appendChild(fieldLabel('Reference files', 'ملفات مرجعية', false));
    const dropzone = el('label', { class: 'dropzone' });
    dropzone.appendChild(svgFromString(UPLOAD_ICON_SVG));
    dropzone.appendChild(el('div', { class: 'title' }, ['Drop files or click to browse']));
    dropzone.appendChild(el('div', { class: 'title-ar' }, ['اسحب الملفات هنا أو انقر للتصفح']));
    dropzone.appendChild(el('div', { class: 'sub' }, ['Logos, photos, past designs']));
    const fileInput = el('input', { type: 'file', multiple: true });
    fileInput.addEventListener('change', handleFiles);
    dropzone.appendChild(fileInput);
    dropzone.addEventListener('dragover', (e) => { e.preventDefault(); dropzone.classList.add('dragover'); });
    dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
    dropzone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropzone.classList.remove('dragover');
      const dropped = Array.from((e.dataTransfer && e.dataTransfer.files) || []);
      if (dropped.length) { state.data.files = state.data.files.concat(dropped); render(); }
    });
    filesField.appendChild(dropzone);

    if (state.data.files.length) {
      const list = el('div', { class: 'file-list' });
      state.data.files.forEach((f, idx) => {
        const row = el('div', { class: 'file-row' });
        row.appendChild(el('span', null, [f.name]));
        row.appendChild(el('button', { type: 'button', onClick: () => removeFile(idx) }, ['×']));
        list.appendChild(row);
      });
      filesField.appendChild(list);
    }
    group.appendChild(filesField);

    const linksField = el('div', { class: 'field' });
    linksField.appendChild(fieldLabel('Reference links', 'روابط مرجعية', false));
    const linksInput = el('input', { type: 'url', placeholder: 'Google Drive, Canva, or inspiration link' });
    linksInput.value = state.data.links;
    linksInput.addEventListener('input', (e) => set('links', e.target.value));
    linksField.appendChild(linksInput);
    group.appendChild(linksField);

    const colorField = el('div', { class: 'field' });
    colorField.appendChild(fieldLabel('Colour / style notes', 'ملاحظات على الألوان والأسلوب', false));
    const colorInput = el('input', { type: 'text', placeholder: 'e.g. Use brand navy, keep it minimal' });
    colorInput.value = state.data.colorNotes;
    colorInput.addEventListener('input', (e) => set('colorNotes', e.target.value));
    colorField.appendChild(colorInput);
    group.appendChild(colorField);

    const avoidField = el('div', { class: 'field' });
    avoidField.appendChild(fieldLabel('Things to avoid', 'ما يجب تجنّبه', false));
    const avoidInput = el('input', { type: 'text', placeholder: 'e.g. No stock photos, avoid red' });
    avoidInput.value = state.data.avoid;
    avoidInput.addEventListener('input', (e) => set('avoid', e.target.value));
    avoidField.appendChild(avoidInput);
    group.appendChild(avoidField);

    wrap.appendChild(group);
    return wrap;
  }

  function renderNav() {
    const nav = el('div', { class: 'nav' });
    if (state.step > 0) {
      const back = el('button', { class: 'back', type: 'button', onClick: () => { state.step -= 1; render(); } });
      back.appendChild(document.createTextNode('Back '));
      back.appendChild(el('span', { dir: 'rtl' }, ['/ رجوع']));
      nav.appendChild(back);
    }
    if (state.step < 4) {
      const can = canProceed(state.step, state.data);
      const next = el('button', { class: 'next', type: 'button', disabled: !can, onClick: () => { if (can) { state.step += 1; render(); } } });
      next.style.opacity = can ? '1' : '0.55';
      next.appendChild(document.createTextNode('Next '));
      next.appendChild(el('span', { dir: 'rtl' }, ['/ التالي']));
      nav.appendChild(next);
    } else {
      const submit = el('button', { class: 'submit', type: 'button', disabled: state.submitting, onClick: submitForm });
      if (state.submitting) {
        submit.textContent = 'Submitting… / جارٍ الإرسال';
      } else {
        submit.appendChild(document.createTextNode('Submit Ticket '));
        submit.appendChild(el('span', { dir: 'rtl' }, ['/ إرسال التذكرة']));
      }
      nav.appendChild(submit);
    }
    return nav;
  }

  function renderForm() {
    const page = el('div', { class: 'page' });
    const wrap = el('div', { class: 'wrap' });
    const card = el('div', { class: 'card' });

    const header = el('div', { class: 'header' });
    header.appendChild(el('div', { class: 'eyebrow' }, ['Design Team']));
    header.appendChild(el('div', { class: 'title' }, ['Design Request Ticket']));
    header.appendChild(el('div', { class: 'title-ar' }, ['تذكرة طلب تصميم']));
    card.appendChild(header);

    card.appendChild(renderProgress());

    const body = el('div', { class: 'body' });
    const steps = [renderStep0, renderStep1, renderStep2, renderStep3, renderStep4];
    body.appendChild(steps[state.step]());
    body.appendChild(renderNav());
    if (state.error) body.appendChild(el('div', { class: 'error-banner' }, [state.error]));
    card.appendChild(body);

    wrap.appendChild(card);
    page.appendChild(wrap);
    return page;
  }

  function renderSuccess() {
    const page = el('div', { class: 'page' });
    const wrap = el('div', { class: 'wrap' });
    const card = el('div', { class: 'card success' });

    const check = el('div', { class: 'check' });
    check.appendChild(svgFromString(CHECK_ICON_SVG));
    card.appendChild(check);
    card.appendChild(el('div', { class: 'headline' }, ['Ticket Submitted']));
    card.appendChild(el('div', { class: 'headline-ar', dir: 'rtl' }, ['تم إرسال التذكرة']));

    const bodyText = el('div', { class: 'body-text' }, [
      'The design team will review your request and reach out via the contact info you provided.',
    ]);
    bodyText.appendChild(el('div', { class: 'ar', dir: 'rtl' }, ['سيقوم فريق التصميم بمراجعة طلبك والتواصل معك عبر بيانات الاتصال المُقدَّمة.']));
    card.appendChild(bodyText);

    if (state.ticketId) {
      card.appendChild(el('div', { class: 'ticket-id' }, [state.ticketId]));
    }

    const resetBtn = el('button', { type: 'button', onClick: resetForm });
    resetBtn.textContent = 'Submit another ticket / إرسال تذكرة أخرى';
    card.appendChild(resetBtn);

    wrap.appendChild(card);
    page.appendChild(wrap);
    return page;
  }

  function fileToPayload(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const result = String(reader.result);
        const base64 = result.slice(result.indexOf(',') + 1);
        resolve({ name: file.name, mimeType: file.type || 'application/octet-stream', data: base64 });
      };
      reader.onerror = () => reject(reader.error || new Error('Could not read file: ' + file.name));
      reader.readAsDataURL(file);
    });
  }

  async function submitForm() {
    if (state.submitting) return;
    state.submitting = true;
    state.error = '';
    render();

    try {
      if (!SCRIPT_URL || SCRIPT_URL.indexOf('PASTE_YOUR') !== -1) {
        throw new Error('The ticket backend is not configured yet — set SCRIPT_URL in config.js.');
      }
      const data = state.data;
      const filePayload = await Promise.all(data.files.map(fileToPayload));
      const payload = {
        fullName: data.fullName,
        team: data.team,
        contact: data.contact,
        title: data.title,
        designType: data.designTypes.join(', '),
        otherDesignType: data.otherDesignType,
        language: data.language,
        brief: data.brief,
        priority: data.priority,
        size: data.size === 'Custom' ? data.customSize : data.size,
        formats: data.fileFormats.join(', '),
        firstDraftDate: data.draftDate,
        finalDate: data.finalDate,
        publishDate: data.publishDate,
        copyText: data.copyText,
        files: filePayload,
        referenceLinks: data.links,
        styleNotes: data.colorNotes,
        avoid: data.avoid,
      };

      // text/plain avoids a CORS preflight, which Apps Script web apps don't handle.
      const res = await fetch(SCRIPT_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain;charset=utf-8' },
        body: JSON.stringify(payload),
      });
      if (!res.ok) throw new Error('Request failed with status ' + res.status);
      const json = await res.json();
      if (!json.ok) throw new Error(json.error || 'Submission failed');

      state.submitting = false;
      state.submitted = true;
      state.ticketId = json.ticketId || '';
      render();
    } catch (err) {
      state.submitting = false;
      state.error = (err && err.message) || String(err);
      render();
    }
  }

  function resetForm() {
    state.step = 0;
    state.submitted = false;
    state.submitting = false;
    state.error = '';
    state.ticketId = '';
    state.data = emptyData();
    render();
  }

  function render() {
    root.innerHTML = '';
    root.appendChild(state.submitted ? renderSuccess() : renderForm());
  }

  render();
})();
