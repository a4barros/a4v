const pathSegments = window.location.pathname.split('/').filter(s => s);
const videoName = pathSegments[0] || 'unknown';

let hasLiked = false;
let viewCounted = false;

async function fetchStats() {
    try {
        const response = await fetch(`/api/stats/${videoName}`);
        const data = await response.json();
        document.getElementById('view-count').textContent = data.views;
        document.getElementById('like-count').textContent = data.likes;

        // Check localStorage for user's like status
        const likedKey = `liked_${videoName}`;
        hasLiked = localStorage.getItem(likedKey) === 'true';
        updateLikeButton();
    } catch (error) {
        console.error('Error fetching stats:', error);
    }
}

async function incrementView() {
    if (viewCounted) return;
    viewCounted = true;

    try {
        const response = await fetch(`/api/stats/${videoName}/view`, { method: 'POST' });
        const data = await response.json();
        document.getElementById('view-count').textContent = data.views;
    } catch (error) {
        console.error('Error incrementing view:', error);
    }
}

async function toggleLike() {
    const endpoint = hasLiked ? 'unlike' : 'like';

    try {
        const response = await fetch(`/api/stats/${videoName}/${endpoint}`, { method: 'POST' });
        const data = await response.json();
        document.getElementById('like-count').textContent = data.likes;

        hasLiked = !hasLiked;
        localStorage.setItem(`liked_${videoName}`, hasLiked);
        updateLikeButton();
    } catch (error) {
        console.error('Error toggling like:', error);
    }
}

function updateLikeButton() {
    const btn = document.getElementById('like-btn');
    if (hasLiked) {
        btn.classList.add('liked');
    } else {
        btn.classList.remove('liked');
    }
}

document.getElementById('like-btn').addEventListener('click', toggleLike);
document.getElementById('video').addEventListener('play', incrementView, { once: true });

fetchStats();
