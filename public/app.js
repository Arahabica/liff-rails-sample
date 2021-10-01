let store = {
    userId: "",
    client: "",
    accessToken: ""
};

window.onload = async function() {
    const res = await fetch('/api/config/liff_id');
    const { liff_id: liffId } = await res.json();
    await liff.init({ liffId });
    // LINEアプリ外で開いた時はログイン処理をする
    if (!liff.isLoggedIn()) {
        liff.login();
    }
    const { userId } = liff.getContext();
    store.userId = userId;
    console.log(liffId, liff.getContext());
    const accessToken = await liff.getAccessToken();
    await signIn(store.userId, accessToken);
    if (!store.accessToken) {
        console.log(accessToken);
        await signUp(store.userId, accessToken);
    }
    const profile = await getProfile();
    console.log(profile);
    showProfile(profile);
};
async function signIn(userId, accessToken) {
    const res = await fetch('/api/auth/sign_in', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
            
        },
        body: JSON.stringify({
            uid: userId,
            access_token: accessToken
        })
    });
    if (res.status === 200) {
        store.client = res.headers.get('client');
        store.accessToken = res.headers.get('access-token');
        return;
    }
    if (res.status !== 401 && res.status !== 404) {
        const data = await res.json();
        console.error(data);
        throw new Error(`Status Code: ${res.status}.`)
    }
}
async function signUp(userId, accessToken) {
    const res = await fetch('/api/auth', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
            
        },
        body: JSON.stringify({
            uid: userId,
            access_token: accessToken
        })
    });
    if (res.status !== 200) {
        const data = await res.json();
        console.error(data);
        throw new Error(`Status Code: ${res.status}.`);
    }
    store.client = res.headers.get('client');
    store.accessToken = res.headers.get('access-token');
}
async function getProfile() {
    const res = await fetch('/api/me', {
        headers: {
            'Content-Type': 'application/json',
            ...getAuthHeaders()
        }
    });
    if (res.status !== 200) {
        const data = await res.json();
        console.error(data);
        throw new Error(`Status Code: ${res.status}.`);
    }
    const data = await res.json();
    return data;
}
function getAuthHeaders() {
    return {
        uid: store.userId,
        client: store.client,
        'access-token': store.accessToken
    }
}
function showProfile(profile) {
    document.getElementById('profileImage').setAttribute('src', profile.image);
    document.getElementById('message').textContent = `ようこそ、${profile.name}さん`
}
