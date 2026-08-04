import { useEffect, useRef, useState } from 'react';
import {
  Avatar,
  Badge,
  Button,
  Empty,
  Form,
  Input,
  Modal,
  Popover,
  Segmented,
  Space,
  Tooltip,
  message,
  type MenuProps,
  Dropdown,
} from 'antd';
import {
  AudioOutlined,
  AppstoreOutlined,
  ArrowLeftOutlined,
  BellOutlined,
  CheckOutlined,
  ClockCircleOutlined,
  CloudOutlined,
  CopyOutlined,
  DeleteOutlined,
  DesktopOutlined,
  EditOutlined,
  FileOutlined,
  FilterOutlined,
  FolderOpenOutlined,
  GiftOutlined,
  HeartOutlined,
  LogoutOutlined,
  MessageOutlined,
  MoreOutlined,
  PhoneOutlined,
  PictureOutlined,
  PlusOutlined,
  ScissorOutlined,
  SearchOutlined,
  SendOutlined,
  SettingOutlined,
  ShareAltOutlined,
  SmileOutlined,
  StopOutlined,
  TeamOutlined,
  UserAddOutlined,
  UserOutlined,
  VideoCameraOutlined,
} from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { reaction } from 'mobx';
import { useNavigate } from 'react-router-dom';
import { chatStore, type ChatMessage, type Contact } from '../stores/chat.store';
import { callStore } from '../stores/call.store';
import { authStore } from '../stores/auth.store';
import {
  apiService,
  type ChatGroupApiResponse,
  type FavoriteItemApiResponse,
  type GroupMessageApiResponse,
} from '../services/api.service';
import { CallType } from '../services/webrtc.service';
import { signalRService } from '../services/signalr.service';
import CallModal from '../components/CallModal';
import CallPage from './CallPage';
import { APP_CONFIG } from '../config/app.config';
import { isAdminEmail } from '../utils/admin.utils';
import {
  gifStickerCategories,
  gifStickers,
  type GifSticker,
  type GifStickerCategoryKey,
} from '../data/gifStickers';
import '../styles/chat.css';
import '../styles/common.css';

const { TextArea } = Input;

type MainView = 'messages' | 'contacts' | 'favorites';
type ContactPanel = 'friends' | 'groups';
type ContactContent = 'profile' | 'requests' | 'groupProfile' | 'groupNotices';
type RequestStatus = 'pending' | 'accepted' | 'rejected';
type RequestDirection = 'incoming' | 'outgoing';
type RequestViewStatus = RequestStatus | 'waiting';
type FavoriteFilter = 'all' | 'chat' | 'media' | 'file' | 'link' | 'note';
type ChatKind = 'contact' | 'group';
type HistoryFilter = 'all' | 'image' | 'emoji' | 'file' | 'link';
type AddContactTab = 'all' | 'user' | 'group' | 'channel' | 'mini' | 'emoji' | 'bot';
type EmojiPanelMode = 'emoji' | 'favorite' | 'gif';
type TranslationProvider = 'browser' | 'local';
type ShareMode = 'share' | 'forward';

interface TranslationResult {
  source: string;
  translated: string;
  provider: TranslationProvider;
}

interface BrowserTranslator {
  translate: (text: string) => Promise<string>;
  destroy?: () => void;
}

interface BrowserTranslatorFactory {
  create?: (options: { sourceLanguage: string; targetLanguage: string }) => Promise<BrowserTranslator>;
}

interface LegacyTranslationApi {
  createTranslator?: (options: { sourceLanguage: string; targetLanguage: string }) => Promise<BrowserTranslator>;
}

interface FriendRequest {
  id: number;
  requester: UserSummary;
  receiver: UserSummary;
  note?: string;
  source?: string;
  status: RequestStatus;
  direction: RequestDirection;
  created_at: string;
  updated_at?: string;
}

interface ContactGroup {
  key: string;
  name: string;
  countText: string;
  contacts: Contact[];
}

interface FavoriteItem {
  id: string;
  content: string;
  type: 'chat' | 'media' | 'file' | 'link' | 'note';
  sourceName: string;
  createdAt: string;
  filePath?: string;
  fileSize?: number;
}

interface LocalChatGroup {
  id: string;
  name: string;
  category: string;
  memberIds: number[];
  members?: UserSummary[];
  pinned?: boolean;
  ownerId?: number;
  announcement?: string;
  note?: string;
  createdAt: string;
  updatedAt?: string;
}

interface LocalGroupMessage {
  id: string;
  groupId: string;
  senderId: number;
  senderName: string;
  content: string;
  type?: number | string;
  filePath?: string;
  fileSize?: number;
  duration?: number;
  createdAt: string;
}

interface HistoryMessageItem {
  id: string;
  kind: ChatKind;
  senderId: number;
  senderName: string;
  senderAvatarPath?: string;
  content: string;
  type?: number | string;
  filePath?: string;
  fileSize?: number;
  duration?: number;
  createdAt: string;
}

interface ShareTarget {
  id: string;
  type: ChatKind;
  name: string;
  avatarPath?: string;
}

interface AttachmentTarget {
  kind: ChatKind;
  contact?: Contact;
  group?: LocalChatGroup;
}

interface GroupMessageSendDraft {
  content: string;
  type?: number;
  file_path?: string;
  file_size?: number;
  duration?: number;
}

interface ForwardMessagePayload {
  content: string;
  type: number;
  file_path?: string;
  file_size?: number;
  duration?: number;
  preview: string;
}

interface UserSummary {
  id?: number;
  username?: string;
  email?: string;
  display_name?: string;
  signature?: string;
  gender?: string;
  birthday?: string;
  country?: string;
  province?: string;
  region?: string;
  avatar_path?: string;
  is_online?: boolean;
}

interface AddContactTarget {
  username: string;
  source: string;
  user?: UserSummary | null;
}

interface WeatherState {
  label: string;
  temperature?: number;
  location: string;
  updatedAt?: string;
}

interface WeatherPosition {
  latitude: number;
  longitude: number;
  location: string;
}

interface ProfileDraft {
  display_name: string;
  signature: string;
  gender: string;
  birthday: string;
  country: string;
  province: string;
  region: string;
}

const DEFAULT_SIGNATURE = '来描绘属于自己的签名吧';
const PROFILE_NAME_MAX_LENGTH = 36;
const PROFILE_SIGNATURE_MAX_LENGTH = 100;
const MAX_ATTACHMENT_SIZE = 20 * 1024 * 1024;
const STORAGE_PREFIX = 'forever-love-chat';
const MESSAGE_TYPES = {
  Text: 1,
  Image: 2,
  Video: 3,
  Audio: 4,
  File: 5,
} as const;
const DEFAULT_WEATHER_POSITION: WeatherPosition = {
  latitude: 31.2304,
  longitude: 121.4737,
  location: '上海',
};

const genderOptions = ['男', '女', '保密'];
const countryOptions = ['中国', '美国', '日本', '韩国', '新加坡', '加拿大', '英国'];
const provinceOptions = ['山东', '北京', '上海', '广东', '江苏', '浙江', '四川'];
const regionOptions = ['青岛', '济南', '北京', '上海', '广州', '深圳', '杭州', '成都'];
const DEFAULT_CONTACT_GROUP_NAME = '默认分组';
const CONTACT_MANAGER_ALL_GROUP = '__all__';
const addContactTabs: Array<{ key: AddContactTab; label: string }> = [
  { key: 'all', label: '全部' },
  { key: 'user', label: '用户' },
  { key: 'group', label: '群聊' },
  { key: 'channel', label: '频道' },
  { key: 'mini', label: '小程序' },
  { key: 'emoji', label: '表情' },
  { key: 'bot', label: '机器人' },
];
const addContactRecommendTags = ['推荐', '同城', '可能认识', '最近活跃', '新注册'];

const emojiSections = [
  {
    title: '最近表情',
    emojis: [
      '😀',
      '😂',
      '🥹',
      '👍',
      '❤️',
      '😎',
      '😳',
      '😍',
      '🙄',
      '😭',
      '😅',
      '🥰',
      '🤔',
      '😇',
      '🤩',
      '🥳',
      '😋',
      '😌',
      '😤',
      '😱',
      '🥺',
      '🤗',
      '👏',
      '🙏',
    ],
  },
  {
    title: '超级表情',
    emojis: [
      '👏',
      '🤝',
      '🎉',
      '🎂',
      '🎁',
      '🌙',
      '⭐',
      '🔥',
      '🌈',
      '✅',
      '❌',
      '🙏',
      '🤗',
      '😴',
      '🤯',
      '😤',
      '😢',
      '😜',
      '😌',
      '😋',
      '🤭',
      '🥲',
      '😱',
      '🥺',
      '🫶',
      '💘',
      '💖',
      '💔',
      '💢',
      '💋',
      '☕',
      '🎈',
      '🎊',
      '🎵',
      '🏀',
      '⚽',
      '💤',
      '💯',
      '💬',
      '✨',
      '⚡',
      '🍉',
      '🍭',
      '🍰',
      '🚀',
      '🚗',
      '🎮',
      '📷',
    ],
  },
  {
    title: '小黄脸表情',
    emojis: [
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😄',
      '😁',
      '😆',
      '😚',
      '😘',
      '😙',
      '😗',
      '😜',
      '🤪',
      '😝',
      '🤤',
      '🤭',
      '🫢',
      '🫣',
      '🤫',
      '🤨',
      '🧐',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '😞',
      '😔',
      '😟',
      '😕',
      '☹️',
      '🙁',
      '😣',
      '😖',
      '😫',
      '😩',
      '🥱',
      '😮‍💨',
      '😮',
      '😲',
      '😯',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😓',
      '🤯',
      '😬',
      '😵‍💫',
      '😵',
      '🥴',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '😷',
      '🤥',
      '🤠',
      '🥸',
      '😈',
      '👿',
    ],
  },
  {
    title: '手势与常用',
    emojis: [
      '👌',
      '🤌',
      '🤏',
      '✌️',
      '🤞',
      '🫰',
      '🤟',
      '🤘',
      '🤙',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐️',
      '🖖',
      '👋',
      '🤲',
      '🙌',
      '🫵',
      '👊',
      '✊',
      '🤛',
      '🤜',
      '👏',
      '👐',
      '🤝',
      '🙏',
      '💪',
      '👀',
      '👂',
      '👃',
      '🧠',
    ],
  },
  {
    title: '爱心与情绪',
    emojis: [
      '🩷',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🤎',
      '🖤',
      '🤍',
      '❤️‍🔥',
      '❤️‍🩹',
      '💕',
      '💞',
      '💓',
      '💗',
      '💝',
      '💟',
      '❣️',
      '💌',
      '💐',
      '🌹',
      '🌷',
      '🌸',
      '🌻',
      '🌼',
      '🪷',
      '🍀',
      '🌟',
      '💫',
      '🫧',
      '🪄',
      '🧸',
    ],
  },
  {
    title: '生活与符号',
    emojis: [
      '🍎',
      '🍓',
      '🍒',
      '🍑',
      '🍜',
      '🍔',
      '🍟',
      '🍿',
      '🍩',
      '🍫',
      '🍻',
      '🥂',
      '🏠',
      '🏖️',
      '🗺️',
      '🛫',
      '🎧',
      '🎤',
      '🎬',
      '🎨',
      '📚',
      '💻',
      '📱',
      '⌚',
      '🔔',
      '📌',
      '📎',
      '🔗',
      '📝',
      '💡',
      '🔒',
      '🎯',
    ],
  },
];

const emojiSearchChips = ['哈哈哈', '在吗', '宝贝', '拜拜', '为什么', '我不知道', '笑死我了', '爱你'];
const localTranslationDictionary: Array<[RegExp, string]> = [
  [/测试用户/g, 'Test user'],
  [/你们已经是好友了/g, 'You are already friends'],
  [/暂无聊天记录/g, 'No chat history yet'],
  [/暂无群聊记录/g, 'No group chat history yet'],
  [/聊天长截图/g, 'Chat long screenshot'],
  [/录屏/g, 'Screen recording'],
  [/语音消息/g, 'Voice message'],
  [/哈哈哈/g, 'Hahaha'],
  [/爱你/g, 'Love you'],
  [/收到/g, 'Got it'],
  [/惊喜/g, 'Surprise'],
  [/在吗/g, 'Are you there?'],
  [/加油/g, 'Keep going'],
  [/图片/g, 'Image'],
  [/视频/g, 'Video'],
  [/语音/g, 'Voice'],
  [/文件/g, 'File'],
  [/群聊/g, 'Group chat'],
  [/消息/g, 'Message'],
  [/好友/g, 'Friend'],
  [/默认分组/g, 'Default group'],
  [/管理员/g, 'Administrator'],
  [/在线/g, 'Online'],
  [/离线/g, 'Offline'],
];

function getTranslationLanguages(text: string) {
  const hasChinese = /[\u3400-\u9fff]/.test(text);
  return {
    sourceLanguage: hasChinese ? 'zh-Hans' : 'en',
    targetLanguage: hasChinese ? 'en' : 'zh-Hans',
  };
}

function translateWithLocalDictionary(text: string) {
  let translated = text;
  localTranslationDictionary.forEach(([pattern, replacement]) => {
    translated = translated.replace(pattern, replacement);
  });

  translated = translated
    .replace(/\[(Image|Video|Voice|File)\]/g, '[$1]')
    .replace(/：/g, ': ')
    .replace(/，/g, ', ')
    .replace(/。/g, '. ');

  return translated === text ? `${text}\n\n(本地词典暂无更多可替换内容)` : translated;
}

async function translateWithBrowserApi(text: string) {
  const { sourceLanguage, targetLanguage } = getTranslationLanguages(text);
  const win = window as Window & {
    Translator?: BrowserTranslatorFactory;
    translation?: LegacyTranslationApi;
  };
  const translator =
    win.Translator?.create
      ? await win.Translator.create({ sourceLanguage, targetLanguage })
      : win.translation?.createTranslator
        ? await win.translation.createTranslator({ sourceLanguage, targetLanguage })
        : null;

  if (!translator) return null;

  try {
    return await translator.translate(text);
  } finally {
    translator.destroy?.();
  }
}

function withTimeout<T>(task: Promise<T>, timeoutMs: number) {
  return new Promise<T>((resolve, reject) => {
    const timer = window.setTimeout(() => reject(new Error('timeout')), timeoutMs);
    task
      .then((value) => {
        window.clearTimeout(timer);
        resolve(value);
      })
      .catch((error) => {
        window.clearTimeout(timer);
        reject(error);
      });
  });
}

function parseDate(timestamp?: string | Date) {
  if (!timestamp) return null;
  const date = timestamp instanceof Date ? timestamp : new Date(timestamp);
  return Number.isNaN(date.getTime()) ? null : date;
}

function pad(value: number) {
  return value.toString().padStart(2, '0');
}

function formatClock(timestamp?: string | Date) {
  const date = parseDate(timestamp);
  if (!date) return '';
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function formatListTime(timestamp?: string | Date) {
  const date = parseDate(timestamp);
  if (!date) return '';
  const now = new Date();
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (sameDay) return formatClock(date);
  if (date.getFullYear() === now.getFullYear()) {
    return `${pad(date.getMonth() + 1)}/${pad(date.getDate())}`;
  }
  return `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(date.getDate())}`;
}

function formatDateLabel(timestamp?: string | Date) {
  const date = parseDate(timestamp);
  if (!date) return '';
  const week = ['日', '一', '二', '三', '四', '五', '六'][date.getDay()];
  return `星期${week} ${formatClock(date)}`;
}

function formatHistoryDate(timestamp?: string | Date) {
  const date = parseDate(timestamp);
  if (!date) return '未知时间';
  return `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(date.getDate())}`;
}

function getUserName(user?: UserSummary | null) {
  return user?.display_name || user?.username || '未命名用户';
}

function getDisplaySignature(user?: UserSummary | null) {
  if (!user || user.signature == null) return DEFAULT_SIGNATURE;
  return user.signature.trim() || '点击编辑个性签名';
}

function getContactSignature(contact?: Contact | null) {
  const signature = contact?.contact_user?.signature;
  return typeof signature === 'string' && signature.trim()
    ? signature.trim()
    : '这个人很低调，暂时没有个性签名';
}

function getContactName(contact?: Contact | null) {
  if (!contact) return '';
  return contact.display_name || getUserName(contact.contact_user);
}

function getInitial(name?: string) {
  return (name || 'U').trim().slice(0, 1).toUpperCase();
}

function normalizeUsername(username?: string | null) {
  return (username || '').trim().toLowerCase();
}

function isAdminSummary(user?: UserSummary | null) {
  return isAdminEmail(user?.email);
}

function isMessageFromCurrentUser(msg: ChatMessage, currentUserId: number) {
  return msg.sender_id === currentUserId;
}

function isMessageInContactConversation(msg: ChatMessage, currentUserId: number, peerUserId?: number) {
  if (!currentUserId || typeof peerUserId !== 'number') return false;

  return (
    (msg.sender_id === currentUserId && msg.receiver_id === peerUserId) ||
    (msg.sender_id === peerUserId && msg.receiver_id === currentUserId)
  );
}

function getErrorMessage(error: unknown, fallback: string) {
  const maybeError = error as { response?: { data?: { message?: unknown } } };
  return typeof maybeError.response?.data?.message === 'string'
    ? maybeError.response.data.message
    : fallback;
}

function normalizeMessageType(type?: number | string) {
  if (typeof type === 'string') return type.toLowerCase();
  if (type === MESSAGE_TYPES.Image) return 'image';
  if (type === MESSAGE_TYPES.Video) return 'video';
  if (type === MESSAGE_TYPES.Audio) return 'audio';
  if (type === MESSAGE_TYPES.File) return 'file';
  return 'text';
}

function getMessageTypeValue(type?: number | string) {
  const normalizedType = normalizeMessageType(type);
  if (normalizedType === 'image') return MESSAGE_TYPES.Image;
  if (normalizedType === 'video') return MESSAGE_TYPES.Video;
  if (normalizedType === 'audio') return MESSAGE_TYPES.Audio;
  if (normalizedType === 'file') return MESSAGE_TYPES.File;
  return MESSAGE_TYPES.Text;
}

function getForwardPreview(payload: Pick<ForwardMessagePayload, 'content' | 'type' | 'file_path'>) {
  const normalizedType = normalizeMessageType(payload.type);
  if (normalizedType === 'image') return payload.content || '[图片]';
  if (normalizedType === 'video') return payload.content || '[视频]';
  if (normalizedType === 'audio') return payload.content || '[语音]';
  if (normalizedType === 'file') return payload.content || '[文件]';
  return payload.content;
}

function isImageMessage(msg: { type?: number | string }) {
  return normalizeMessageType(msg.type) === 'image';
}

function isAudioMessage(msg: { type?: number | string }) {
  return normalizeMessageType(msg.type) === 'audio';
}

function isVideoMessage(msg: { type?: number | string }) {
  return normalizeMessageType(msg.type) === 'video';
}

function isFileMessage(msg: { type?: number | string }) {
  return normalizeMessageType(msg.type) === 'file';
}

function formatFileSize(size?: number) {
  if (!size || size <= 0) return '';
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${(size / 1024 / 1024).toFixed(1)} MB`;
}

function formatScreenshotFileName() {
  const now = new Date();
  return `screenshot-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.png`;
}

function formatVoiceFileName() {
  const now = new Date();
  return `voice-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.webm`;
}

function formatScreenRecordingFileName() {
  const now = new Date();
  return `screen-recording-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.webm`;
}

function formatLongScreenshotFileName() {
  const now = new Date();
  return `chat-longshot-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.png`;
}

function getScreenRecordingMimeType() {
  if (typeof MediaRecorder === 'undefined' || !MediaRecorder.isTypeSupported) return '';
  return ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'].find((type) =>
    MediaRecorder.isTypeSupported(type)
  ) || '';
}

function getWesternZodiac(month: number, day: number) {
  const signs = [
    ['摩羯座', 20],
    ['水瓶座', 19],
    ['双鱼座', 21],
    ['白羊座', 20],
    ['金牛座', 21],
    ['双子座', 22],
    ['巨蟹座', 23],
    ['狮子座', 23],
    ['处女座', 23],
    ['天秤座', 24],
    ['天蝎座', 23],
    ['射手座', 22],
  ] as const;

  return day < signs[month - 1][1] ? signs[(month + 10) % 12][0] : signs[month - 1][0];
}

function parseBirthday(birthday?: string | null) {
  if (!birthday) return null;
  const date = new Date(birthday);
  return Number.isNaN(date.getTime()) ? null : date;
}

function formatAge(birthday?: string | null) {
  const date = parseBirthday(birthday);
  if (!date) return '年龄未填';

  const now = new Date();
  let age = now.getFullYear() - date.getFullYear();
  const hasHadBirthday =
    now.getMonth() > date.getMonth() ||
    (now.getMonth() === date.getMonth() && now.getDate() >= date.getDate());
  if (!hasHadBirthday) age -= 1;

  return age >= 0 ? `${age}岁` : '年龄未填';
}

function formatBirthdayLabel(birthday?: string | null) {
  const date = parseBirthday(birthday);
  if (!date) return '生日未填';

  const month = date.getMonth() + 1;
  const day = date.getDate();
  return `${month}月${day}日 ${getWesternZodiac(month, day)}`;
}

function formatLocation(user?: UserSummary | null) {
  const parts = [user?.country, user?.province, user?.region].filter(Boolean);
  return parts.length > 0 ? `现居 ${parts.join('·')}` : '现居 未填写';
}

function formatTextAreaCount({ count, maxLength }: { count: number; maxLength?: number }) {
  return typeof maxLength === 'number' ? `${count}/${maxLength}` : String(count);
}

function getFriendRequestDirection(request: FriendRequest, currentUserId?: number): RequestDirection | null {
  const requesterId = request.requester?.id;
  const receiverId = request.receiver?.id;

  if (typeof requesterId === 'number' && typeof receiverId === 'number' && requesterId === receiverId) {
    return null;
  }

  if (currentUserId) {
    if (requesterId === currentUserId && receiverId !== currentUserId) return 'outgoing';
    if (receiverId === currentUserId && requesterId !== currentUserId) return 'incoming';
  }

  return request.direction;
}

function getFriendRequestPeer(request: FriendRequest, currentUserId?: number) {
  const direction = getFriendRequestDirection(request, currentUserId);
  if (direction === 'incoming') return request.requester;
  if (direction === 'outgoing') return request.receiver;
  return null;
}

function shouldShowFriendRequest(request: FriendRequest, currentUserId?: number) {
  const peer = getFriendRequestPeer(request, currentUserId);
  return Boolean(peer && (!currentUserId || peer.id !== currentUserId));
}

function getFriendRequestStatus(request: FriendRequest, currentUserId?: number): RequestViewStatus {
  if (request.status === 'pending' && getFriendRequestDirection(request, currentUserId) === 'outgoing') return 'waiting';
  return request.status;
}

function getFriendRequestActionText(request: FriendRequest, currentUserId?: number) {
  return request.status === 'pending' && getFriendRequestDirection(request, currentUserId) === 'outgoing'
    ? '正在验证你的邀请'
    : '请求加为好友';
}

function getWeatherLabel(code: number) {
  if (code === 0) return '晴';
  if (code === 1 || code === 2) return '多云';
  if (code === 3) return '阴';
  if (code === 45 || code === 48) return '雾';
  if (code >= 51 && code <= 57) return '毛毛雨';
  if (code >= 61 && code <= 67) return '雨';
  if (code >= 71 && code <= 77) return '雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 85 && code <= 86) return '阵雪';
  if (code >= 95 && code <= 99) return '雷雨';
  return '天气';
}

function resolveWeatherPosition(): Promise<WeatherPosition> {
  if (!navigator.geolocation) {
    return Promise.resolve(DEFAULT_WEATHER_POSITION);
  }

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        resolve({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          location: '当前位置',
        });
      },
      () => resolve(DEFAULT_WEATHER_POSITION),
      {
        enableHighAccuracy: false,
        maximumAge: 10 * 60 * 1000,
        timeout: 5000,
      }
    );
  });
}

function createProfileDraft(user?: UserSummary | null): ProfileDraft {
  return {
    display_name: (user?.display_name || user?.username || '').slice(0, PROFILE_NAME_MAX_LENGTH),
    signature: (user?.signature || '').slice(0, PROFILE_SIGNATURE_MAX_LENGTH),
    gender: user?.gender || '男',
    birthday: user?.birthday || '',
    country: user?.country || '中国',
    province: user?.province || '',
    region: user?.region || '',
  };
}

function getProfileOptions(options: string[], currentValue: string) {
  return currentValue && !options.includes(currentValue) ? [currentValue, ...options] : options;
}

function getLocalKey(userId: number | string | undefined, name: string) {
  return `${STORAGE_PREFIX}:${userId || 'guest'}:${name}`;
}

function readLocalJson<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function writeLocalJson<T>(key: string, value: T) {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(key, JSON.stringify(value));
}

function normalizeContactGroupName(name: string) {
  return name.trim().replace(/\s+/g, ' ').slice(0, 24);
}

function mergeContactGroupNames(names: string[], assignments: Record<string, string>) {
  const merged = [
    DEFAULT_CONTACT_GROUP_NAME,
    ...names,
    ...Object.values(assignments),
  ]
    .map((name) => normalizeContactGroupName(name))
    .filter(Boolean);

  return Array.from(new Set(merged));
}

function createLocalId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
}

function getFavoriteType(msg: ChatMessage): FavoriteItem['type'] {
  if (isImageMessage(msg) || isVideoMessage(msg)) return 'media';
  if (isFileMessage(msg)) return 'file';
  return getContentFavoriteType(msg.content);
}

function getContentFavoriteType(content: string): FavoriteItem['type'] {
  if (/^https?:\/\//i.test(content) || content.includes('http')) return 'link';
  return 'chat';
}

function mapApiGroup(group: ChatGroupApiResponse): LocalChatGroup {
  return {
    id: String(group.id),
    name: group.name || '未命名的群聊',
    category: group.category || '我创建的群聊',
    memberIds: group.member_ids || [],
    members: group.members || [],
    pinned: Boolean(group.pinned),
    ownerId: group.owner_id,
    announcement: group.announcement,
    note: group.note,
    createdAt: group.created_at,
    updatedAt: group.updated_at,
  };
}

function mapApiGroupMessage(message: GroupMessageApiResponse): LocalGroupMessage {
  return {
    id: String(message.id),
    groupId: String(message.group_id),
    senderId: message.sender_id,
    senderName: message.sender_name || getUserName(message.sender),
    content: message.content,
    type: message.type ?? MESSAGE_TYPES.Text,
    filePath: message.file_path,
    fileSize: message.file_size,
    duration: message.duration,
    createdAt: message.created_at || message.timestamp || new Date().toISOString(),
  };
}

function mapApiFavorite(item: FavoriteItemApiResponse): FavoriteItem {
  return {
    id: String(item.id),
    content: item.content,
    type: item.type,
    sourceName: item.source_name,
    createdAt: item.created_at,
    filePath: item.file_path,
    fileSize: item.file_size,
  };
}

function isBackendId(id: string) {
  return /^\d+$/.test(id);
}

const ChatPage = observer(() => {
  const navigate = useNavigate();
  const initialContactGroupAssignments = readLocalJson<Record<string, string>>(
    getLocalKey(authStore.user?.id, 'contact-groups'),
    {}
  );
  const initialContactGroupNames = readLocalJson<string[]>(
    getLocalKey(authStore.user?.id, 'contact-group-names'),
    []
  );
  const [mainView, setMainView] = useState<MainView>('messages');
  const [contactPanel, setContactPanel] = useState<ContactPanel>('friends');
  const [contactContent, setContactContent] = useState<ContactContent>('profile');
  const [activeChatKind, setActiveChatKind] = useState<ChatKind>('contact');
  const [activeGroupId, setActiveGroupId] = useState<string>('');
  const [mobileContentOpen, setMobileContentOpen] = useState(false);
  const [messageText, setMessageText] = useState('');
  const [groupMessageText, setGroupMessageText] = useState('');
  const [searchText, setSearchText] = useState('');
  const [favoriteSearchText, setFavoriteSearchText] = useState('');
  const [favoriteFilter, setFavoriteFilter] = useState<FavoriteFilter>('all');
  const [favoriteNoteVisible, setFavoriteNoteVisible] = useState(false);
  const [favoriteNoteDraft, setFavoriteNoteDraft] = useState('');
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [groupNameDraft, setGroupNameDraft] = useState('');
  const [groupCategoryDraft, setGroupCategoryDraft] = useState('我创建的群聊');
  const [selectedGroupMemberIds, setSelectedGroupMemberIds] = useState<number[]>([]);
  const [shareVisible, setShareVisible] = useState(false);
  const [shareMode, setShareMode] = useState<ShareMode>('share');
  const [sharePayload, setSharePayload] = useState('');
  const [forwardPayload, setForwardPayload] = useState<ForwardMessagePayload | null>(null);
  const [shareSearchText, setShareSearchText] = useState('');
  const [shareNote, setShareNote] = useState('');
  const [selectedShareTargetIds, setSelectedShareTargetIds] = useState<string[]>([]);
  const [addContactVisible, setAddContactVisible] = useState(false);
  const [addContactTab, setAddContactTab] = useState<AddContactTab>('all');
  const [contactManagerVisible, setContactManagerVisible] = useState(false);
  const [contactManagerGroup, setContactManagerGroup] = useState(CONTACT_MANAGER_ALL_GROUP);
  const [contactManagerSearchText, setContactManagerSearchText] = useState('');
  const [contactGroupCreateVisible, setContactGroupCreateVisible] = useState(false);
  const [contactGroupDraft, setContactGroupDraft] = useState('');
  const [contactUsername, setContactUsername] = useState('');
  const [contactNote, setContactNote] = useState('');
  const [addContactRequestVisible, setAddContactRequestVisible] = useState(false);
  const [addContactTarget, setAddContactTarget] = useState<AddContactTarget | null>(null);
  const [addContactSubmitting, setAddContactSubmitting] = useState(false);
  const [searchUsersLoading, setSearchUsersLoading] = useState(false);
  const [recommendationLoading, setRecommendationLoading] = useState(false);
  const [lastUserSearchQuery, setLastUserSearchQuery] = useState('');
  const [userResults, setUserResults] = useState<UserSummary[]>([]);
  const [recommendedUsers, setRecommendedUsers] = useState<UserSummary[]>([]);
  const [editDisplayNameVisible, setEditDisplayNameVisible] = useState(false);
  const [displayNameForm] = Form.useForm();
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [emojiPanelMode, setEmojiPanelMode] = useState<EmojiPanelMode>('emoji');
  const [emojiSearchText, setEmojiSearchText] = useState('');
  const [gifCategory, setGifCategory] = useState<GifStickerCategoryKey>('smileys');
  const [historyVisible, setHistoryVisible] = useState(false);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyMode, setHistoryMode] = useState<ChatKind>('contact');
  const [historyTitle, setHistoryTitle] = useState('聊天记录');
  const [historyMessages, setHistoryMessages] = useState<HistoryMessageItem[]>([]);
  const [historyQuery, setHistoryQuery] = useState('');
  const [historyFilter, setHistoryFilter] = useState<HistoryFilter>('all');
  const [signatureVisible, setSignatureVisible] = useState(false);
  const [signatureDraft, setSignatureDraft] = useState('');
  const [signatureSaving, setSignatureSaving] = useState(false);
  const [profileVisible, setProfileVisible] = useState(false);
  const [profileDraft, setProfileDraft] = useState<ProfileDraft>(() => createProfileDraft(authStore.user));
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileAvatarUploading, setProfileAvatarUploading] = useState(false);
  const [weather, setWeather] = useState<WeatherState>({
    label: '天气获取中',
    location: DEFAULT_WEATHER_POSITION.location,
  });
  const [profileContact, setProfileContact] = useState<Contact | null>(null);
  const [expandedGroups, setExpandedGroups] = useState<Record<string, boolean>>({
    favorites: true,
    friends: true,
    friendNotice: true,
    'friend-request-pending': true,
    'friend-request-outgoing': true,
    'friend-request-handled': false,
  });
  const [activeFriendRequestSection, setActiveFriendRequestSection] = useState('friend-request-pending');
  const [activeGroupNoticeSection, setActiveGroupNoticeSection] = useState('group-notice-join');
  const [friendRequests, setFriendRequests] = useState<FriendRequest[]>([]);
  const [friendRequestsLoading, setFriendRequestsLoading] = useState(false);
  const [attachmentUploading, setAttachmentUploading] = useState(false);
  const [isRecordingVoice, setIsRecordingVoice] = useState(false);
  const [voiceRecordSeconds, setVoiceRecordSeconds] = useState(0);
  const [isScreenRecording, setIsScreenRecording] = useState(false);
  const [privacyMaskVisible, setPrivacyMaskVisible] = useState(false);
  const [translationVisible, setTranslationVisible] = useState(false);
  const [translationLoading, setTranslationLoading] = useState(false);
  const [translationResult, setTranslationResult] = useState<TranslationResult | null>(null);
  const [contactGroupAssignments, setContactGroupAssignments] = useState<Record<string, string>>(
    initialContactGroupAssignments
  );
  const [contactGroupNames, setContactGroupNames] = useState<string[]>(() =>
    mergeContactGroupNames(initialContactGroupNames, initialContactGroupAssignments)
  );
  const [favoriteItems, setFavoriteItems] = useState<FavoriteItem[]>(() =>
    readLocalJson(getLocalKey(authStore.user?.id, 'favorites'), [])
  );
  const [localGroups, setLocalGroups] = useState<LocalChatGroup[]>(() =>
    readLocalJson(getLocalKey(authStore.user?.id, 'groups'), [])
  );
  const [localGroupMessages, setLocalGroupMessages] = useState<LocalGroupMessage[]>(() =>
    readLocalJson(getLocalKey(authStore.user?.id, 'group-messages'), [])
  );
  const [mutedGroupIds, setMutedGroupIds] = useState<string[]>(() =>
    readLocalJson(getLocalKey(authStore.user?.id, 'muted-groups'), [])
  );
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const didPickInitialContact = useRef(false);
  const profileAvatarInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const voiceRecorderRef = useRef<MediaRecorder | null>(null);
  const voiceStreamRef = useRef<MediaStream | null>(null);
  const voiceChunksRef = useRef<Blob[]>([]);
  const voiceStartedAtRef = useRef(0);
  const voiceTimerRef = useRef<number | null>(null);
  const voiceCancelledRef = useRef(false);
  const voiceTargetRef = useRef<AttachmentTarget | null>(null);
  const screenRecorderRef = useRef<MediaRecorder | null>(null);
  const screenStreamRef = useRef<MediaStream | null>(null);
  const screenChunksRef = useRef<Blob[]>([]);
  const screenStartedAtRef = useRef(0);
  const screenTargetRef = useRef<AttachmentTarget | null>(null);

  useEffect(() => {
    return () => {
      if (voiceTimerRef.current !== null) {
        window.clearInterval(voiceTimerRef.current);
        voiceTimerRef.current = null;
      }
      voiceCancelledRef.current = true;
      const recorder = voiceRecorderRef.current;
      if (recorder?.state === 'recording') {
        recorder.onstop = null;
        recorder.stop();
      }
      voiceStreamRef.current?.getTracks().forEach((track) => track.stop());
      voiceStreamRef.current = null;
      voiceRecorderRef.current = null;
      voiceTargetRef.current = null;
      const screenRecorder = screenRecorderRef.current;
      if (screenRecorder?.state === 'recording') {
        screenRecorder.onstop = null;
        screenRecorder.stop();
      }
      screenStreamRef.current?.getTracks().forEach((track) => track.stop());
      screenStreamRef.current = null;
      screenRecorderRef.current = null;
      screenTargetRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!authStore.isAuthenticated) {
      navigate('/login');
      return;
    }

    const ensureSignalRConnection = async () => {
      if (!signalRService.isConnected && authStore.token && authStore.user) {
        try {
          await signalRService.connect(authStore.token);
          await signalRService.authenticate(authStore.user.id);
        } catch (error) {
          console.error('SignalR connection failed:', error);
        }
      } else if (signalRService.isConnected && authStore.user) {
        try {
          await signalRService.authenticate(authStore.user.id);
        } catch (error) {
          console.error('SignalR authentication failed:', error);
        }
      }
    };

    void ensureSignalRConnection();
    void chatStore.loadContacts();
    void loadFriendRequests();
  }, [navigate]);

  useEffect(() => {
    const dispose = reaction(
      () => chatStore.contacts.length,
      (contactsLength) => {
        if (contactsLength === 0) return;

        const firstContact = chatStore.contacts[0];
        if (!didPickInitialContact.current && !chatStore.currentContact) {
          didPickInitialContact.current = true;
          chatStore.setCurrentContact(firstContact);
        }
        setProfileContact((current) => current || firstContact);
      },
      { fireImmediately: true }
    );

    return () => dispose();
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 80);
    return () => window.clearTimeout(timer);
  });

  useEffect(() => {
    let cancelled = false;

    const loadWeather = async () => {
      try {
        const position = await resolveWeatherPosition();
        const response = await fetch(
          `https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code&timezone=auto`
        );
        const data = await response.json();
        const current = data.current;

        if (!cancelled && current) {
          setWeather({
            label: getWeatherLabel(Number(current.weather_code)),
            temperature: Math.round(Number(current.temperature_2m)),
            location: position.location,
            updatedAt: current.time,
          });
        }
      } catch {
        if (!cancelled) {
          setWeather({
            label: '天气暂不可用',
            location: DEFAULT_WEATHER_POSITION.location,
          });
        }
      }
    };

    void loadWeather();
    const interval = window.setInterval(() => void loadWeather(), 10 * 60 * 1000);

    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, []);

  const currentUserId = authStore.user?.id || 0;
  const currentUserName = authStore.user?.display_name || authStore.user?.username || '我的账号';
  const currentUsername = normalizeUsername(authStore.user?.username);
  const currentSignature = getDisplaySignature(authStore.user);

  useEffect(() => {
    const nextContactGroupAssignments = readLocalJson<Record<string, string>>(
      getLocalKey(currentUserId, 'contact-groups'),
      {}
    );
    const nextContactGroupNames = readLocalJson<string[]>(getLocalKey(currentUserId, 'contact-group-names'), []);
    setContactGroupAssignments(nextContactGroupAssignments);
    setContactGroupNames(mergeContactGroupNames(nextContactGroupNames, nextContactGroupAssignments));
    setContactManagerGroup(CONTACT_MANAGER_ALL_GROUP);
    setFavoriteItems(readLocalJson(getLocalKey(currentUserId, 'favorites'), []));
    setLocalGroups(readLocalJson(getLocalKey(currentUserId, 'groups'), []));
    setLocalGroupMessages(readLocalJson(getLocalKey(currentUserId, 'group-messages'), []));
    setMutedGroupIds(readLocalJson(getLocalKey(currentUserId, 'muted-groups'), []));
    void loadFavorites();
    void loadChatGroups();
  }, [currentUserId]);

  useEffect(() => {
    if (activeGroupId) {
      void loadGroupMessages(activeGroupId);
    }
  }, [activeGroupId, currentUserId]);

  useEffect(() => {
    writeLocalJson(getLocalKey(currentUserId, 'contact-groups'), contactGroupAssignments);
  }, [contactGroupAssignments, currentUserId]);

  useEffect(() => {
    writeLocalJson(getLocalKey(currentUserId, 'contact-group-names'), contactGroupNames);
  }, [contactGroupNames, currentUserId]);

  useEffect(() => {
    writeLocalJson(getLocalKey(currentUserId, 'favorites'), favoriteItems);
  }, [favoriteItems, currentUserId]);

  useEffect(() => {
    writeLocalJson(getLocalKey(currentUserId, 'groups'), localGroups);
  }, [localGroups, currentUserId]);

  useEffect(() => {
    writeLocalJson(getLocalKey(currentUserId, 'group-messages'), localGroupMessages);
  }, [localGroupMessages, currentUserId]);

  useEffect(() => {
    writeLocalJson(getLocalKey(currentUserId, 'muted-groups'), mutedGroupIds);
  }, [mutedGroupIds, currentUserId]);

  const openProfileSettings = () => {
    setProfileDraft(createProfileDraft(authStore.user));
    setProfileVisible(true);
  };

  const updateProfileDraft = (field: keyof ProfileDraft, value: string) => {
    const nextValue =
      field === 'display_name'
        ? value.slice(0, PROFILE_NAME_MAX_LENGTH)
        : field === 'signature'
          ? value.slice(0, PROFILE_SIGNATURE_MAX_LENGTH)
          : value;

    setProfileDraft((current) => ({
      ...current,
      [field]: nextValue,
    }));
  };

  const getApiAssetUrl = (path: string | undefined, allowedPrefix: '/avatar/' | '/chat-files/', cacheBust = false) => {
    if (!path || !path.startsWith(allowedPrefix)) return undefined;

    try {
      const apiBase = new URL(APP_CONFIG.API_BASE_URL);
      const assetUrl = new URL(path, apiBase);
      if (assetUrl.origin !== apiBase.origin || !assetUrl.pathname.startsWith(allowedPrefix)) {
        return undefined;
      }
      if (cacheBust) {
        assetUrl.searchParams.set('t', Date.now().toString());
      }
      return assetUrl.toString();
    } catch {
      return undefined;
    }
  };

  const getAvatarUrl = (avatarPath?: string) => {
    if (avatarPath && /^https:\/\//i.test(avatarPath)) return avatarPath;
    return getApiAssetUrl(avatarPath, '/avatar/', true);
  };

  const getAttachmentUrl = (filePath?: string) => {
    return getApiAssetUrl(filePath, '/chat-files/');
  };

  const loadFavorites = async () => {
    if (!currentUserId) return;

    try {
      const response = await apiService.getFavorites();
      if (response.success && response.data) {
        setFavoriteItems(response.data.map(mapApiFavorite));
      }
    } catch {
      // Keep the local cache visible when the backend is unavailable.
    }
  };

  const loadChatGroups = async () => {
    if (!currentUserId) return;

    try {
      const response = await apiService.getChatGroups();
      if (response.success && response.data) {
        setLocalGroups(response.data.map(mapApiGroup));
      }
    } catch {
      // Keep the local cache visible when the backend is unavailable.
    }
  };

  const loadGroupMessages = async (groupId: string) => {
    if (!currentUserId || !isBackendId(groupId)) return;

    try {
      const response = await apiService.getGroupMessages(Number(groupId));
      if (response.success && response.data) {
        const remoteMessages = response.data.map(mapApiGroupMessage);
        setLocalGroupMessages((messages) => [
          ...messages.filter((msg) => msg.groupId !== groupId),
          ...remoteMessages,
        ]);
      }
    } catch {
      // Keep the local cache visible when the backend is unavailable.
    }
  };

  const handleProfileAvatarChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';

    if (!file) return;
    if (!file.type.startsWith('image/')) {
      message.error('只能上传图片文件');
      return;
    }
    if (file.size / 1024 / 1024 >= 5) {
      message.error('图片大小不能超过 5MB');
      return;
    }

    const formData = new FormData();
    formData.append('avatar', file);
    setProfileAvatarUploading(true);

    try {
      const response = await fetch(`${APP_CONFIG.API_BASE_URL}/api/auth/upload-avatar`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authStore.token}`,
        },
        body: formData,
      });
      const result = await response.json();
      if (result.success && result.data) {
        authStore.user = result.data;
        localStorage.setItem('user', JSON.stringify(result.data));
        message.success('头像已更新');
      } else {
        message.error(result.message || '头像上传失败');
      }
    } catch {
      message.error('头像上传失败');
    } finally {
      setProfileAvatarUploading(false);
    }
  };

  const handleSaveProfile = async () => {
    const displayName = profileDraft.display_name.trim();

    if (!displayName) {
      message.warning('昵称不能为空');
      return;
    }

    setProfileSaving(true);
    try {
      const response = await apiService.updateProfile({
        display_name: displayName,
        signature: profileDraft.signature.trim(),
        gender: profileDraft.gender,
        birthday: profileDraft.birthday,
        country: profileDraft.country,
        province: profileDraft.province,
        region: profileDraft.region,
      });

      if (response.success && response.data) {
        authStore.user = response.data;
        localStorage.setItem('user', JSON.stringify(response.data));
        setProfileVisible(false);
        message.success('资料已保存');
      } else {
        message.error(response.message || '资料保存失败');
      }
    } catch (error) {
      message.error(getErrorMessage(error, '资料保存失败'));
    } finally {
      setProfileSaving(false);
    }
  };

  const filteredContacts = chatStore.contacts.filter((contact) => {
    const keyword = searchText.trim().toLowerCase();
    if (!keyword) return true;
    const name = getContactName(contact).toLowerCase();
    const username = contact.contact_user?.username?.toLowerCase() || '';
    return name.includes(keyword) || username.includes(keyword);
  });

  const visibleFriendRequests = friendRequests.filter((request) => shouldShowFriendRequest(request, currentUserId));
  const pendingRequestCount = visibleFriendRequests.filter(
    (item) => item.status === 'pending' && getFriendRequestDirection(item, currentUserId) === 'incoming'
  ).length;
  const activeGroup = localGroups.find((group) => group.id === activeGroupId) || null;
  const activeGroupMessages = activeGroup
    ? localGroupMessages.filter((msg) => msg.groupId === activeGroup.id)
    : [];
  const allGroupMembers: UserSummary[] = activeGroup
    ? activeGroup.members && activeGroup.members.length > 0
      ? activeGroup.members
      : [
        authStore.user as UserSummary | null,
        ...chatStore.contacts
          .filter((contact) => {
            const memberId = contact.contact_user?.id;
            return typeof memberId === 'number' && activeGroup.memberIds.includes(memberId);
          })
          .map((contact) => contact.contact_user as UserSummary),
      ].filter((user): user is UserSummary => Boolean(user))
    : [];
  const allShareTargets: ShareTarget[] = [
    ...chatStore.contacts.map((contact) => ({
      id: `contact-${contact.id}`,
      type: 'contact' as const,
      name: getContactName(contact),
      avatarPath: contact.contact_user?.avatar_path,
    })),
    ...localGroups.map((group) => ({
      id: `group-${group.id}`,
      type: 'group' as const,
      name: group.name,
    })),
  ];
  const recentShareTargets = allShareTargets.filter((target) =>
    target.name.toLowerCase().includes(shareSearchText.trim().toLowerCase())
  );
  const selectedShareTargets = allShareTargets.filter((target) => selectedShareTargetIds.includes(target.id));
  const filteredFavoriteItems = favoriteItems.filter((item) => {
    const keyword = favoriteSearchText.trim().toLowerCase();
    const filterMatches = favoriteFilter === 'all' || item.type === favoriteFilter;
    const keywordMatches =
      !keyword ||
      item.content.toLowerCase().includes(keyword) ||
      item.sourceName.toLowerCase().includes(keyword);
    return filterMatches && keywordMatches;
  });
  const favoriteCounts = favoriteItems.reduce<Record<FavoriteFilter, number>>(
    (counts, item) => {
      counts.all += 1;
      counts[item.type] += 1;
      return counts;
    },
    { all: 0, chat: 0, media: 0, file: 0, link: 0, note: 0 }
  );
  const incomingPendingRequests = visibleFriendRequests.filter(
    (request) => request.status === 'pending' && getFriendRequestDirection(request, currentUserId) === 'incoming'
  );
  const outgoingPendingRequests = visibleFriendRequests.filter(
    (request) => request.status === 'pending' && getFriendRequestDirection(request, currentUserId) === 'outgoing'
  );
  const handledRequests = visibleFriendRequests.filter((request) => request.status !== 'pending');
  const friendRequestSections = [
    {
      key: 'friend-request-pending',
      title: '新的朋友',
      count: incomingPendingRequests.length,
      description: '需要你确认的好友申请',
      requests: incomingPendingRequests,
      emptyText: '暂无待处理申请',
    },
    {
      key: 'friend-request-outgoing',
      title: '我发出的',
      count: outgoingPendingRequests.length,
      description: '等待对方通过的验证消息',
      requests: outgoingPendingRequests,
      emptyText: '暂无等待验证的邀请',
    },
    {
      key: 'friend-request-handled',
      title: '已处理',
      count: handledRequests.length,
      description: '同意或拒绝过的历史通知',
      requests: handledRequests,
      emptyText: '暂无已处理记录',
    },
  ];
  const groupNoticeSections = [
    {
      key: 'group-notice-join',
      title: '加群申请',
      count: 0,
    },
    {
      key: 'group-notice-invite',
      title: '群邀请',
      count: 0,
    },
    {
      key: 'group-notice-handled',
      title: '已处理',
      count: 0,
    },
  ];
  const pendingGroupNoticeCount = groupNoticeSections
    .filter((section) => section.key !== 'group-notice-handled')
    .reduce((total, section) => total + section.count, 0);
  const totalGroupNoticeCount = groupNoticeSections.reduce((total, section) => total + section.count, 0);
  const friendRequestUsernameMap = new Map(
    visibleFriendRequests
      .map((request) => {
        const peer = getFriendRequestPeer(request, currentUserId);
        const username = normalizeUsername(peer?.username);
        return username ? [username, request] as const : null;
      })
      .filter((item): item is readonly [string, FriendRequest] => Boolean(item))
  );
  const existingContactUsernames = new Set(
    chatStore.contacts
      .map((contact) => contact.contact_user?.username)
      .filter((username): username is string => Boolean(username))
      .map((username) => normalizeUsername(username))
  );
  const filterPotentialUsers = (users: UserSummary[]) => {
    const seen = new Set<string>();
    return users.filter((user) => {
      const username = normalizeUsername(user.username);
      const key = username || String(user.id || '');
      if (!key || seen.has(key)) return false;
      seen.add(key);
      if (isAdminSummary(user)) return false;
      if (user.id === currentUserId || username === currentUsername) return false;
      if (username && existingContactUsernames.has(username)) return false;
      return true;
    });
  };
  const visibleUserResults = filterPotentialUsers(userResults);
  const visibleRecommendedUsers = filterPotentialUsers(recommendedUsers).slice(0, 12);
  const getContactGroupName = (contact?: Contact | null) => {
    if (!contact) return DEFAULT_CONTACT_GROUP_NAME;
    const assignedGroup = normalizeContactGroupName(contactGroupAssignments[String(contact.id)] || '');
    return assignedGroup || DEFAULT_CONTACT_GROUP_NAME;
  };
  const profileContactGroupName = getContactGroupName(profileContact);

  const contactGroups: ContactGroup[] = contactGroupNames
    .map((groupName) => {
      const contacts = filteredContacts.filter(
        (contact) => getContactGroupName(contact) === groupName
      );
      return {
        key: groupName,
        name: groupName,
        countText: `${contacts.length}`,
        contacts,
      };
    });
  const contactManagerGroups = contactGroupNames.map((groupName) => ({
    name: groupName,
    count: chatStore.contacts.filter((contact) => getContactGroupName(contact) === groupName).length,
  }));
  const contactManagerKeyword = contactManagerSearchText.trim().toLowerCase();
  const contactManagerContacts = chatStore.contacts.filter((contact) => {
    const groupMatches =
      contactManagerGroup === CONTACT_MANAGER_ALL_GROUP ||
      getContactGroupName(contact) === contactManagerGroup;
    const keywordMatches =
      !contactManagerKeyword ||
      getContactName(contact).toLowerCase().includes(contactManagerKeyword) ||
      (contact.contact_user?.username || '').toLowerCase().includes(contactManagerKeyword) ||
      (contact.display_name || '').toLowerCase().includes(contactManagerKeyword);
    return groupMatches && keywordMatches;
  });

  const filteredLocalGroups = localGroups.filter((group) => {
    const keyword = searchText.trim().toLowerCase();
    return !keyword || group.name.toLowerCase().includes(keyword);
  });
  const groupCategories = ['置顶群聊', '未命名的群聊', '我创建的群聊', '我加入的群聊'].map((category) => {
    const groups = filteredLocalGroups.filter((group) => {
      if (category === '置顶群聊') return group.pinned;
      if (category === '我创建的群聊') return !group.pinned && group.ownerId === currentUserId;
      if (category === '我加入的群聊') return !group.pinned && group.ownerId !== currentUserId;
      return !group.name.trim();
    });
    return { category, groups };
  });
  const activeGroupMuted = activeGroup ? mutedGroupIds.includes(activeGroup.id) : false;
  const activeGroupOwner = activeGroup
    ? allGroupMembers.find((member) => member.id === activeGroup.ownerId)
    : null;
  const activeGroupOwnerName = activeGroup?.ownerId === currentUserId
    ? currentUserName
    : getUserName(activeGroupOwner);
  const activeGroupMemberPreview = allGroupMembers.slice(0, 10);
  const conversationRows = [
    ...filteredContacts.map((contact) => {
      const sortDate = parseDate(contact.last_message_at || contact.added_at);
      return {
        id: `contact-${contact.id}`,
        kind: 'contact' as const,
        active: activeChatKind === 'contact' && chatStore.currentContact?.id === contact.id,
        title: getContactName(contact),
        time: formatListTime(contact.last_message_at || contact.added_at),
        preview: contact.last_message_at ? '最近有新的聊天记录' : '你们已经是好友了',
        sortTime: sortDate?.getTime() || 0,
        unread: contact.unread_count || 0,
        pinned: false,
        muted: false,
        contact,
      };
    }),
    ...filteredLocalGroups.map((group) => {
      const groupMessages = localGroupMessages.filter((msg) => msg.groupId === group.id);
      const latest = groupMessages[groupMessages.length - 1];
      const sortDate = parseDate(latest?.createdAt || group.updatedAt || group.createdAt);
      const latestType = normalizeMessageType(latest?.type);
      const latestPreview = latest
        ? latestType === 'image'
          ? '[图片]'
          : latestType === 'audio'
            ? `[语音] ${latest.duration || 1}"`
            : latestType === 'file'
              ? `[文件] ${latest.content || '附件'}`
              : latest.content
        : `${group.memberIds.length + 1} 位成员`;
      return {
        id: `group-${group.id}`,
        kind: 'group' as const,
        active: activeChatKind === 'group' && activeGroupId === group.id,
        title: group.name,
        time: formatListTime(latest?.createdAt || group.updatedAt || group.createdAt),
        preview: latestPreview,
        sortTime: sortDate?.getTime() || 0,
        unread: 0,
        pinned: Boolean(group.pinned),
        muted: mutedGroupIds.includes(group.id),
        group,
      };
    }),
  ].sort((left, right) => Number(right.pinned) - Number(left.pinned) || right.sortTime - left.sortTime);

  const filteredHistoryMessages = historyMessages.filter((msg) => {
    const keyword = historyQuery.trim().toLowerCase();
    if (keyword && !`${msg.senderName} ${msg.content}`.toLowerCase().includes(keyword)) return false;
    const messageType = normalizeMessageType(msg.type);
    if (historyFilter === 'emoji') {
      return emojiSections.some((section) => section.emojis.some((emoji) => msg.content.includes(emoji)));
    }
    if (historyFilter === 'image') return messageType === 'image' || messageType === 'video';
    if (historyFilter === 'file') return isFileMessage(msg);
    if (historyFilter === 'link') return /^https?:\/\//i.test(msg.content) || msg.content.includes('http');
    return true;
  });

  const contactMenuItems: MenuProps['items'] = [
    {
      key: 'edit-name',
      label: '修改备注',
      icon: <EditOutlined />,
      onClick: () => {
        if (chatStore.currentContact) {
          displayNameForm.setFieldsValue({
            display_name: chatStore.currentContact.display_name || '',
          });
          setEditDisplayNameVisible(true);
        }
      },
    },
    {
      key: 'history',
      label: '聊天记录',
      icon: <ClockCircleOutlined />,
      onClick: () => {
        void openHistory();
      },
    },
    {
      key: 'remove',
      label: '删除好友',
      icon: <DeleteOutlined />,
      danger: true,
      onClick: () => {
        void handleRemoveContact();
      },
    },
  ];

  const railItems: Array<{ key: MainView; label: string; icon: React.ReactNode; badge?: number }> = [
    { key: 'messages', label: '消息', icon: <MessageOutlined />, badge: chatStore.totalUnreadCount },
    { key: 'contacts', label: '联系人', icon: <UserOutlined />, badge: pendingRequestCount },
    { key: 'favorites', label: '收藏', icon: <HeartOutlined /> },
  ];

  const getCurrentAttachmentTarget = (): AttachmentTarget | null => {
    if (activeChatKind === 'group') {
      return activeGroup ? { kind: 'group', group: activeGroup } : null;
    }

    return chatStore.currentContact ? { kind: 'contact', contact: chatStore.currentContact } : null;
  };

  const createLocalGroupMessageFromDraft = (
    group: LocalChatGroup,
    draft: GroupMessageSendDraft
  ): LocalGroupMessage => ({
    id: createLocalId('group-message'),
    groupId: group.id,
    senderId: currentUserId,
    senderName: currentUserName,
    content: draft.content,
    type: draft.type ?? MESSAGE_TYPES.Text,
    filePath: draft.file_path,
    fileSize: draft.file_size,
    duration: draft.duration,
    createdAt: new Date().toISOString(),
  });

  const sendGroupMessagePayload = async (
    group: LocalChatGroup,
    draft: GroupMessageSendDraft,
    options?: { allowOfflineFallback?: boolean }
  ) => {
    const content = draft.content.trim();
    if (!content) return false;

    let savedMessage: LocalGroupMessage;
    try {
      if (isBackendId(group.id)) {
        const response = await apiService.sendGroupMessage(Number(group.id), {
          content,
          type: draft.type ?? MESSAGE_TYPES.Text,
          file_path: draft.file_path,
          file_size: draft.file_size,
          duration: draft.duration,
        });

        if (!response.success || !response.data) {
          message.error(response.message || '发送失败');
          return false;
        }

        savedMessage = mapApiGroupMessage(response.data);
      } else {
        savedMessage = createLocalGroupMessageFromDraft(group, {
          ...draft,
          content,
        });
      }
    } catch (error: unknown) {
      const hasServerResponse = Boolean((error as { response?: unknown }).response);
      if (hasServerResponse || options?.allowOfflineFallback === false) {
        message.error(getErrorMessage(error, '发送失败'));
        return false;
      }

      message.warning(getErrorMessage(error, '后端不可用，已发送本地群消息'));
      savedMessage = createLocalGroupMessageFromDraft(group, {
        ...draft,
        content,
      });
    }

    setLocalGroupMessages((messages) => [...messages, savedMessage]);
    void loadChatGroups();
    return true;
  };

  const handleSendMessage = async () => {
    const text = messageText.trim();
    if (!text || !chatStore.currentContact) return;

    const result = await chatStore.sendMessage(chatStore.currentContact.contact_user.id, text);
    if (result.success) {
      setMessageText('');
      setEmojiOpen(false);
      void chatStore.loadContacts();
    } else {
      message.error(result.message || '发送失败');
    }
  };

  const sendAttachment = async (
    file: File,
    type: number,
    options?: { content?: string; duration?: number; successText?: string; target?: AttachmentTarget | null }
  ) => {
    const target = options?.target ?? getCurrentAttachmentTarget();
    if (!target || (target.kind === 'contact' && !target.contact) || (target.kind === 'group' && !target.group)) {
      message.warning('请先选择一个会话');
      return;
    }

    if (file.size > MAX_ATTACHMENT_SIZE) {
      message.warning('文件大小不能超过 20MB');
      return;
    }

    setAttachmentUploading(true);
    try {
      const uploadResponse = await apiService.uploadChatFile(file);
      if (!uploadResponse.success || !uploadResponse.data) {
        message.error(uploadResponse.message || '文件上传失败');
        return;
      }

      const content = options?.content || uploadResponse.data.file_name || file.name;
      const filePath = uploadResponse.data.file_path;
      const fileSize = Number(uploadResponse.data.file_size || file.size);
      let result: { success: boolean; message?: string };

      if (target.kind === 'group' && target.group) {
        const sent = await sendGroupMessagePayload(target.group, {
          content,
          type,
          file_path: filePath,
          file_size: fileSize,
          duration: options?.duration,
        });
        if (sent) {
          message.success(options?.successText || (type === MESSAGE_TYPES.Image ? '图片已发送' : '文件已发送'));
        }
        return;
      } else if (target.contact && target.contact.id !== chatStore.currentContact?.id) {
        const response = await apiService.sendMessage({
          receiver_id: target.contact.contact_user.id,
          content,
          type,
          file_path: filePath,
          file_size: fileSize,
          duration: options?.duration,
        });
        result = { success: response.success, message: response.message };
      } else if (target.contact) {
        result = await chatStore.sendMessage(target.contact.contact_user.id, content, {
          type,
          file_path: filePath,
          file_size: fileSize,
          duration: options?.duration,
        });
      } else {
        result = { success: false, message: '请先选择一个会话' };
      }

      if (result.success) {
        message.success(options?.successText || (type === MESSAGE_TYPES.Image ? '图片已发送' : '文件已发送'));
        void chatStore.loadContacts();
      } else {
        message.error(result.message || '发送失败');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '文件发送失败'));
    } finally {
      setAttachmentUploading(false);
    }
  };

  const handleAttachmentSelect = async (event: React.ChangeEvent<HTMLInputElement>, type: number) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    await sendAttachment(file, type);
  };

  const appendEmoji = (emoji: string) => {
    if (activeChatKind === 'group') {
      setGroupMessageText((value) => `${value}${emoji}`);
    } else {
      setMessageText((value) => `${value}${emoji}`);
    }
  };

  const sendGifSticker = async (sticker: GifSticker) => {
    const target = getCurrentAttachmentTarget();
    if (!target) {
      message.warning('请先选择一个会话');
      return;
    }

    setEmojiOpen(false);
    try {
      const response = await fetch(sticker.src, { mode: 'cors' });
      if (!response.ok) {
        throw new Error(`sticker fetch failed: ${response.status}`);
      }
      const blob = await response.blob();
      await sendAttachment(new File([blob], `${sticker.id}.png`, { type: 'image/png' }), MESSAGE_TYPES.Image, {
        content: sticker.title,
        successText: '动态表情已发送',
        target,
      });
    } catch (error: unknown) {
      message.error(getErrorMessage(error, 'GIF 发送失败'));
    }
  };

  const getConversationSnapshotRows = () => {
    if (activeChatKind === 'group') {
      return activeGroupMessages.slice(-100).map((msg) => {
        const type = normalizeMessageType(msg.type);
        const prefix =
          type === 'image' ? '[图片] ' :
          type === 'video' ? '[视频] ' :
          type === 'audio' ? '[语音] ' :
          type === 'file' ? '[文件] ' : '';
        return {
          mine: msg.senderId === currentUserId,
          sender: msg.senderId === currentUserId ? currentUserName : msg.senderName,
          time: formatClock(msg.createdAt),
          content: `${prefix}${msg.content || '消息'}`,
        };
      });
    }

    return chatStore.messages.slice(-100).map((msg) => {
      const prefix =
        isImageMessage(msg) ? '[图片] ' :
        isVideoMessage(msg) ? '[视频] ' :
        isAudioMessage(msg) ? '[语音] ' :
        isFileMessage(msg) ? '[文件] ' : '';
      return {
        mine: isMessageFromCurrentUser(msg, currentUserId),
        sender: isMessageFromCurrentUser(msg, currentUserId)
          ? currentUserName
          : getContactName(chatStore.currentContact),
        time: formatClock(msg.created_at),
        content: `${prefix}${msg.content || '消息'}`,
      };
    });
  };

  const getCurrentConversationTitle = () => {
    if (activeChatKind === 'group') return activeGroup?.name || '群聊';
    return getContactName(chatStore.currentContact) || '聊天';
  };

  const collectCurrentConversationText = () => {
    return getConversationSnapshotRows()
      .map((row) => `[${row.time || '--:--'}] ${row.sender}: ${row.content}`)
      .join('\n');
  };

  const copyTextToClipboard = async (text: string) => {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return;
    }

    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.setAttribute('readonly', 'true');
    textArea.style.position = 'fixed';
    textArea.style.left = '-9999px';
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand('copy');
    document.body.removeChild(textArea);
  };

  const createConversationSnapshotBlob = async () => {
    const rows = getConversationSnapshotRows();
    if (rows.length === 0) return null;

    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d');
    if (!context) return null;

    const width = 900;
    const padding = 28;
    const bubbleMaxWidth = 620;
    const lineHeight = 24;
    const title = getCurrentConversationTitle();

    const wrapText = (text: string, maxWidth: number) => {
      const lines: string[] = [];
      let line = '';
      Array.from(text).forEach((char) => {
        const nextLine = `${line}${char}`;
        if (line && context.measureText(nextLine).width > maxWidth) {
          lines.push(line);
          line = char;
        } else {
          line = nextLine;
        }
      });
      if (line) lines.push(line);
      return lines.length > 0 ? lines : [''];
    };

    context.font = '15px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
    const preparedRows = rows.map((row) => ({
      ...row,
      lines: wrapText(row.content, bubbleMaxWidth - 42),
    }));
    const height = Math.min(
      12000,
      92 + preparedRows.reduce((sum, row) => sum + Math.max(54, 28 + row.lines.length * lineHeight) + 14, 0)
    );

    canvas.width = width;
    canvas.height = height;
    context.fillStyle = '#eef4f8';
    context.fillRect(0, 0, width, height);
    context.fillStyle = '#12a8f4';
    context.fillRect(0, 0, width, 58);
    context.fillStyle = '#ffffff';
    context.font = '700 20px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
    context.fillText(title, padding, 36);
    context.font = '13px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
    context.fillText(`聊天长截图 · ${formatDateLabel(new Date())}`, width - 230, 36);

    let y = 82;
    preparedRows.forEach((row) => {
      const bubbleHeight = Math.max(48, 26 + row.lines.length * lineHeight);
      if (y + bubbleHeight + 24 > height) return;

      const bubbleWidth = Math.min(
        bubbleMaxWidth,
        Math.max(160, Math.max(...row.lines.map((line) => context.measureText(line).width)) + 42)
      );
      const x = row.mine ? width - padding - bubbleWidth : padding;
      context.fillStyle = row.mine ? '#95ec69' : '#ffffff';
      context.beginPath();
      if (typeof context.roundRect === 'function') {
        context.roundRect(x, y, bubbleWidth, bubbleHeight, 10);
      } else {
        context.rect(x, y, bubbleWidth, bubbleHeight);
      }
      context.fill();

      context.fillStyle = '#7c8793';
      context.font = '12px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
      context.fillText(`${row.sender} ${row.time}`, x + 18, y + 18);
      context.fillStyle = '#111820';
      context.font = '15px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
      row.lines.forEach((line, index) => {
        context.fillText(line, x + 18, y + 42 + index * lineHeight);
      });
      y += bubbleHeight + 14;
    });

    return new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'));
  };

  const handleVoiceButtonClick = async () => {
    if (isRecordingVoice) {
      voiceRecorderRef.current?.stop();
      return;
    }

    const target = getCurrentAttachmentTarget();
    if (!target) {
      message.warning('请先选择一个会话');
      return;
    }

    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
      message.warning('当前浏览器不支持录音');
      return;
    }

    try {
      voiceCancelledRef.current = false;
      voiceTargetRef.current = target;
      voiceChunksRef.current = [];
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      voiceStreamRef.current = stream;
      voiceRecorderRef.current = recorder;
      voiceStartedAtRef.current = Date.now();
      setVoiceRecordSeconds(0);
      setIsRecordingVoice(true);

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          voiceChunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => {
        if (voiceTimerRef.current !== null) {
          window.clearInterval(voiceTimerRef.current);
          voiceTimerRef.current = null;
        }
        voiceStreamRef.current?.getTracks().forEach((track) => track.stop());
        voiceStreamRef.current = null;
        voiceRecorderRef.current = null;
        setIsRecordingVoice(false);

        if (voiceCancelledRef.current) {
          voiceChunksRef.current = [];
          setVoiceRecordSeconds(0);
          voiceTargetRef.current = null;
          return;
        }

        const duration = Math.max(1, Math.round((Date.now() - voiceStartedAtRef.current) / 1000));
        const chunks = voiceChunksRef.current;
        voiceChunksRef.current = [];
        setVoiceRecordSeconds(duration);
        if (chunks.length === 0) {
          message.warning('没有录到声音');
          voiceTargetRef.current = null;
          return;
        }

        const blob = new Blob(chunks, { type: recorder.mimeType || 'audio/webm' });
        const file = new File([blob], formatVoiceFileName(), { type: blob.type || 'audio/webm' });
        void sendAttachment(file, MESSAGE_TYPES.Audio, {
          content: `语音消息 ${duration}"`,
          duration,
          successText: '语音已发送',
          target: voiceTargetRef.current,
        });
        voiceTargetRef.current = null;
      };

      recorder.start();
      voiceTimerRef.current = window.setInterval(() => {
        setVoiceRecordSeconds(Math.max(1, Math.round((Date.now() - voiceStartedAtRef.current) / 1000)));
      }, 500);
    } catch (error: unknown) {
      voiceStreamRef.current?.getTracks().forEach((track) => track.stop());
      voiceStreamRef.current = null;
      voiceRecorderRef.current = null;
      voiceTargetRef.current = null;
      setIsRecordingVoice(false);
      setVoiceRecordSeconds(0);
      message.error(getErrorMessage(error, '录音失败'));
    }
  };

  const handleScreenshot = async () => {
    const target = getCurrentAttachmentTarget();
    if (!target) {
      message.warning('请先选择一个会话');
      return;
    }

    if (!navigator.mediaDevices?.getDisplayMedia) {
      message.info('当前环境不支持直接截图，请选择截图图片发送');
      imageInputRef.current?.click();
      return;
    }

    let stream: MediaStream | null = null;
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
      const video = document.createElement('video');
      video.srcObject = stream;
      video.muted = true;
      video.playsInline = true;
      await new Promise<void>((resolve) => {
        video.onloadedmetadata = () => resolve();
      });
      await video.play();

      await new Promise<void>((resolve) => {
        requestAnimationFrame(() => resolve());
      });

      const canvas = document.createElement('canvas');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const context = canvas.getContext('2d');
      if (!context || canvas.width === 0 || canvas.height === 0) {
        message.error('截图失败');
        return;
      }

      context.drawImage(video, 0, 0, canvas.width, canvas.height);
      const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/png'));
      if (!blob) {
        message.error('截图失败');
        return;
      }

      await sendAttachment(new File([blob], formatScreenshotFileName(), { type: 'image/png' }), MESSAGE_TYPES.Image, {
        target,
      });
    } catch (error: unknown) {
      if ((error as { name?: string }).name !== 'NotAllowedError') {
        message.error('截图失败');
      }
    } finally {
      stream?.getTracks().forEach((track) => track.stop());
    }
  };

  const handleScreenRecording = async () => {
    const recording = screenRecorderRef.current;
    if (recording?.state === 'recording') {
      recording.stop();
      return;
    }

    const target = getCurrentAttachmentTarget();
    if (!target) {
      message.warning('请先选择一个会话');
      return;
    }

    if (!navigator.mediaDevices?.getDisplayMedia || typeof MediaRecorder === 'undefined') {
      message.warning('当前浏览器不支持录屏');
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: true });
      const mimeType = getScreenRecordingMimeType();
      const recorder = mimeType ? new MediaRecorder(stream, { mimeType }) : new MediaRecorder(stream);
      screenStreamRef.current = stream;
      screenRecorderRef.current = recorder;
      screenChunksRef.current = [];
      screenStartedAtRef.current = Date.now();
      screenTargetRef.current = target;
      setIsScreenRecording(true);

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          screenChunksRef.current.push(event.data);
        }
      };

      recorder.onstop = () => {
        const chunks = screenChunksRef.current;
        const recordingTarget = screenTargetRef.current;
        const duration = Math.max(1, Math.round((Date.now() - screenStartedAtRef.current) / 1000));
        screenChunksRef.current = [];
        screenTargetRef.current = null;
        screenRecorderRef.current = null;
        screenStreamRef.current?.getTracks().forEach((track) => track.stop());
        screenStreamRef.current = null;
        setIsScreenRecording(false);

        if (chunks.length === 0 || !recordingTarget) {
          message.warning('没有录到屏幕内容');
          return;
        }

        const blob = new Blob(chunks, { type: recorder.mimeType || 'video/webm' });
        const file = new File([blob], formatScreenRecordingFileName(), { type: blob.type || 'video/webm' });
        void sendAttachment(file, MESSAGE_TYPES.Video, {
          content: `录屏 ${duration}s`,
          duration,
          successText: '录屏已发送',
          target: recordingTarget,
        });
      };

      stream.getVideoTracks().forEach((track) => {
        track.onended = () => {
          if (recorder.state === 'recording') {
            recorder.stop();
          }
        };
      });
      recorder.start(1000);
      message.info('录屏中，再次点击录屏可停止');
    } catch (error: unknown) {
      screenStreamRef.current?.getTracks().forEach((track) => track.stop());
      screenStreamRef.current = null;
      screenRecorderRef.current = null;
      screenTargetRef.current = null;
      setIsScreenRecording(false);
      if ((error as { name?: string }).name !== 'NotAllowedError') {
        message.error(getErrorMessage(error, '录屏失败'));
      }
    }
  };

  const handleLongScreenshot = async () => {
    const target = getCurrentAttachmentTarget();
    if (!target) {
      message.warning('请先选择一个会话');
      return;
    }

    const blob = await createConversationSnapshotBlob();
    if (!blob) {
      message.info('当前会话暂无可生成的长截图');
      return;
    }

    await sendAttachment(new File([blob], formatLongScreenshotFileName(), { type: 'image/png' }), MESSAGE_TYPES.Image, {
      content: `聊天长截图 - ${getCurrentConversationTitle()}`,
      successText: '长截图已发送',
      target,
    });
  };

  const handleExtractChatText = async () => {
    const text = collectCurrentConversationText();
    if (!text.trim()) {
      message.info('当前会话暂无可提取文字');
      return;
    }

    try {
      await copyTextToClipboard(text);
      message.success('已提取并复制当前会话文字');
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '提取文字失败'));
    }
  };

  const handleTranslateScreenText = async () => {
    const text = collectCurrentConversationText();
    if (!text.trim()) {
      message.info('当前会话暂无可翻译文字');
      return;
    }

    setTranslationResult({
      source: text,
      translated: '',
      provider: 'local',
    });
    setTranslationVisible(true);
    setTranslationLoading(true);

    const fallback = () => ({
      source: text,
      translated: translateWithLocalDictionary(text),
      provider: 'local' as const,
    });

    try {
      const translated = await withTimeout(translateWithBrowserApi(text), 1500);
      setTranslationResult(
        translated?.trim()
          ? { source: text, translated, provider: 'browser' }
          : fallback()
      );
    } catch {
      setTranslationResult(fallback());
    } finally {
      setTranslationLoading(false);
    }
  };

  const handleHideCurrentWindow = () => {
    setPrivacyMaskVisible(true);
    window.setTimeout(() => setPrivacyMaskVisible(false), 5000);
    message.info('已临时隐藏聊天内容，点击遮罩可立即恢复');
  };

  const screenshotToolItems: MenuProps['items'] = [
    { key: 'screenshot', icon: <ScissorOutlined />, label: '截图' },
    { key: 'record', icon: <VideoCameraOutlined />, label: isScreenRecording ? '停止录屏' : '录屏' },
    { key: 'longshot', icon: <PictureOutlined />, label: '长截图' },
    { key: 'extract', icon: <FileOutlined />, label: '提取文字' },
    { key: 'translate', icon: <CloudOutlined />, label: '屏幕翻译' },
    { key: 'hide', icon: <StopOutlined />, label: '隐藏当前窗口' },
  ];

  const handleScreenshotToolClick: MenuProps['onClick'] = ({ key }) => {
    if (key === 'screenshot') void handleScreenshot();
    if (key === 'record') void handleScreenRecording();
    if (key === 'longshot') void handleLongScreenshot();
    if (key === 'extract') void handleExtractChatText();
    if (key === 'translate') void handleTranslateScreenText();
    if (key === 'hide') handleHideCurrentWindow();
  };

  const renderScreenshotToolButton = () => (
    <Dropdown
      trigger={['click']}
      placement="topLeft"
      classNames={{ root: 'screenshot-tool-dropdown' }}
      menu={{ items: screenshotToolItems, onClick: handleScreenshotToolClick }}
    >
      <Button
        type="text"
        icon={<ScissorOutlined />}
        loading={attachmentUploading && !isScreenRecording}
        className={isScreenRecording ? 'screenshot-tool-button recording' : 'screenshot-tool-button'}
        aria-label="截图工具"
      />
    </Dropdown>
  );

  const handleComposerPaste = async (event: React.ClipboardEvent<HTMLTextAreaElement>) => {
    const imageFile = Array.from(event.clipboardData.files).find((file) => file.type.startsWith('image/'));
    if (!imageFile) return;

    event.preventDefault();
    const fileName = imageFile.name && imageFile.name !== 'image.png'
      ? imageFile.name
      : formatScreenshotFileName();
    await sendAttachment(
      new File([imageFile], fileName, { type: imageFile.type || 'image/png' }),
      MESSAGE_TYPES.Image,
      {
        content: fileName,
        successText: '截图已发送',
      }
    );
  };

  const openSignatureEditor = () => {
    setSignatureDraft(authStore.user?.signature ?? '');
    setSignatureVisible(true);
  };

  const handleSaveSignature = async () => {
    if (signatureDraft.length > 100) {
      message.warning('个性签名不能超过100个字符');
      return;
    }

    setSignatureSaving(true);
    try {
      const response = await apiService.updateProfile({ signature: signatureDraft });
      if (response.success && response.data) {
        authStore.user = response.data;
        localStorage.setItem('user', JSON.stringify(response.data));
        setSignatureVisible(false);
        message.success('个性签名已更新');
      } else {
        message.error(response.message || '更新失败');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '更新失败'));
    } finally {
      setSignatureSaving(false);
    }
  };

  const loadFriendRequests = async () => {
    setFriendRequestsLoading(true);
    try {
      const response = await apiService.getFriendRequests();
      if (response.success && response.data) {
        setFriendRequests(response.data);
      } else {
        setFriendRequests([]);
      }
    } catch (error: unknown) {
      setFriendRequests([]);
      message.error(getErrorMessage(error, '好友通知加载失败'));
    } finally {
      setFriendRequestsLoading(false);
    }
  };

  const loadRecommendedUsers = async () => {
    setRecommendationLoading(true);
    try {
      const response = await apiService.searchUsers('', 1, 24);
      setRecommendedUsers(response.success && response.data ? response.data.users || [] : []);
    } catch {
      setRecommendedUsers([]);
    } finally {
      setRecommendationLoading(false);
    }
  };

  const openAddContactDialog = () => {
    setAddContactVisible(true);
    setAddContactTab('all');
    setLastUserSearchQuery('');
    setUserResults([]);
    void loadRecommendedUsers();
  };

  const openContactManager = () => {
    setContactManagerVisible(true);
    setContactManagerGroup(CONTACT_MANAGER_ALL_GROUP);
    setContactManagerSearchText('');
  };

  const handleSearchUsers = async (value = contactUsername) => {
    const keyword = value.trim();
    if (!keyword) {
      setLastUserSearchQuery('');
      setUserResults([]);
      void loadRecommendedUsers();
      return;
    }

    setContactUsername(keyword);
    setAddContactTab('user');
    setLastUserSearchQuery(keyword);
    setSearchUsersLoading(true);
    try {
      const response = await apiService.searchUsers(keyword, 1, 20);
      if (response.success && response.data) {
        setUserResults(response.data.users || []);
      } else {
        setUserResults([]);
        message.error(response.message || '搜索失败');
      }
    } catch (error: unknown) {
      setUserResults([]);
      message.error(getErrorMessage(error, '搜索失败'));
    } finally {
      setSearchUsersLoading(false);
    }
  };

  const getDefaultFriendRequestNote = () => {
    const accountName = authStore.user?.display_name?.trim() || authStore.user?.username?.trim() || currentUserName;
    return `我是${accountName}，请求添加你为好友`;
  };

  const openAddContactRequest = (username = contactUsername, source = '账号搜索', user?: UserSummary | null) => {
    const targetUsername = username.trim();
    if (!targetUsername) {
      message.warning('请输入用户名');
      return;
    }
    if (user && isAdminSummary(user)) {
      message.warning('管理员账号不支持添加为好友');
      return;
    }

    setAddContactTarget({ username: targetUsername, source, user });
    setContactNote(getDefaultFriendRequestNote());
    setAddContactRequestVisible(true);
  };

  const handleAddContact = async () => {
    const target = addContactTarget;
    const targetUsername = target?.username.trim() || contactUsername.trim();
    if (!targetUsername) {
      message.warning('请输入用户名');
      return;
    }
    if (target?.user && isAdminSummary(target.user)) {
      message.warning('管理员账号不支持添加为好友');
      return;
    }

    setAddContactSubmitting(true);
    try {
      const response = await apiService.createFriendRequest({
        username: targetUsername,
        note: contactNote.trim() || undefined,
        source: target?.source || '账号搜索',
      });

      if (!response.success) {
        message.error(response.message || '发送好友申请失败');
        return;
      }

      message.success(response.message || '好友申请已发送');
      setAddContactRequestVisible(false);
      setAddContactTarget(null);
      await loadFriendRequests();
      setContactNote('');
      void loadRecommendedUsers();
      if (response.data?.direction === 'incoming') {
        setMainView('contacts');
        setContactContent('requests');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '发送好友申请失败'));
    } finally {
      setAddContactSubmitting(false);
    }
  };

  const handleFriendRequest = async (request: FriendRequest, status: 'accepted' | 'rejected') => {
    try {
      const response = await apiService.respondFriendRequest(request.id, status);
      if (response.success) {
        message.success(response.message || (status === 'accepted' ? '已同意好友申请' : '已拒绝好友申请'));
        await chatStore.loadContacts();
        await loadFriendRequests();
      } else {
        message.error(response.message || '处理好友申请失败');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '处理好友申请失败'));
    }
  };

  const handleClearHandledRequests = async () => {
    try {
      const response = await apiService.clearHandledFriendRequests();
      if (response.success) {
        message.success(response.message || '已清理处理过的好友申请');
        await loadFriendRequests();
      } else {
        message.error(response.message || '清理好友申请失败');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '清理好友申请失败'));
    }
  };

  const handleInitiateCall = async (type: CallType, targetContact: Contact | null = chatStore.currentContact) => {
    if (!targetContact) return;

    await chatStore.loadContacts(false);
    const latestContact =
      chatStore.contacts.find((contact) => contact.contact_user?.id === targetContact.contact_user.id) ||
      targetContact;

    if (!latestContact.contact_user.is_online) {
      Modal.warning({
        title: '对方当前离线',
        content: '离线用户暂时无法接收通话。',
      });
      return;
    }

    try {
      await callStore.initiateCall(
        latestContact.contact_user.id,
        type,
        latestContact.contact_user
      );
    } catch {
      message.error('发起通话失败');
    }
  };

  const handleLogout = () => {
    Modal.confirm({
      title: '退出登录',
      content: '确定要退出当前账号吗？',
      okText: '退出',
      cancelText: '取消',
      onOk: async () => {
        await authStore.logout();
        navigate('/');
      },
    });
  };

  const handleRemoveContact = async () => {
    if (!chatStore.currentContact) return;

    Modal.confirm({
      title: '删除好友',
      content: `确定删除 ${getContactName(chatStore.currentContact)} 吗？`,
      okText: '删除',
      okButtonProps: { danger: true },
      cancelText: '取消',
      onOk: async () => {
        try {
          const response = await apiService.removeContact(chatStore.currentContact!.id);
          if (response.success) {
            message.success('好友已删除');
            chatStore.setCurrentContact(null);
            await chatStore.loadContacts();
          } else {
            message.error(response.message || '删除失败');
          }
        } catch (error: unknown) {
          message.error(getErrorMessage(error, '删除失败'));
        }
      },
    });
  };

  const handleUpdateDisplayName = async (values: { display_name: string }) => {
    if (!chatStore.currentContact) return;

    const result = await chatStore.updateDisplayName(chatStore.currentContact.id, values.display_name);
    if (result.success) {
      message.success('备注已更新');
      setEditDisplayNameVisible(false);
      displayNameForm.resetFields();
    } else {
      message.error(result.message || '更新失败');
    }
  };

  const resetHistorySearch = () => {
    setHistoryQuery('');
    setHistoryFilter('all');
  };

  const mapContactHistoryMessage = (msg: ChatMessage, contact: Contact): HistoryMessageItem => {
    const isMine = isMessageFromCurrentUser(msg, currentUserId);
    return {
      id: String(msg.id),
      kind: 'contact',
      senderId: msg.sender_id,
      senderName: isMine ? currentUserName : getContactName(contact),
      senderAvatarPath: isMine ? authStore.user?.avatar_path : contact.contact_user?.avatar_path,
      content: msg.content,
      type: msg.type,
      filePath: msg.file_path,
      fileSize: msg.file_size,
      duration: msg.duration,
      createdAt: msg.created_at || msg.timestamp,
    };
  };

  const getGroupSender = (group: LocalChatGroup, senderId: number) => {
    if (senderId === currentUserId) return authStore.user as UserSummary | null;
    return (
      group.members?.find((member) => member.id === senderId) ||
      chatStore.contacts.find((contact) => contact.contact_user?.id === senderId)?.contact_user ||
      null
    );
  };

  const mapGroupHistoryMessage = (msg: LocalGroupMessage, group: LocalChatGroup): HistoryMessageItem => {
    const sender = getGroupSender(group, msg.senderId);
    return {
      id: msg.id,
      kind: 'group',
      senderId: msg.senderId,
      senderName: msg.senderId === currentUserId ? currentUserName : msg.senderName || getUserName(sender),
      senderAvatarPath: sender?.avatar_path,
      content: msg.content,
      type: msg.type,
      filePath: msg.filePath,
      fileSize: msg.fileSize,
      duration: msg.duration,
      createdAt: msg.createdAt,
    };
  };

  const sortHistoryMessages = (messages: HistoryMessageItem[]) =>
    [...messages].sort((a, b) => {
      const left = parseDate(a.createdAt)?.getTime() || 0;
      const right = parseDate(b.createdAt)?.getTime() || 0;
      return left - right;
    });

  const openHistory = async () => {
    const contact = chatStore.currentContact;
    if (!contact) return;

    setHistoryVisible(true);
    setHistoryLoading(true);
    setHistoryMode('contact');
    setHistoryTitle(getContactName(contact) || '聊天记录');
    resetHistorySearch();
    try {
      const response = await apiService.getChatHistory(contact.id);
      const messages = response.success && response.data ? response.data : chatStore.messages;
      setHistoryMessages(sortHistoryMessages(messages.map((msg) => mapContactHistoryMessage(msg, contact))));
    } catch {
      setHistoryMessages(sortHistoryMessages(chatStore.messages.map((msg) => mapContactHistoryMessage(msg, contact))));
    } finally {
      setHistoryLoading(false);
      void chatStore.loadContacts(false);
    }
  };

  const openGroupHistory = async () => {
    if (!activeGroup) return;

    const group = activeGroup;
    setHistoryVisible(true);
    setHistoryLoading(true);
    setHistoryMode('group');
    setHistoryTitle(`群聊记录 - ${group.name}`);
    resetHistorySearch();

    let messages = localGroupMessages.filter((msg) => msg.groupId === group.id);

    try {
      if (isBackendId(group.id)) {
        const response = await apiService.getGroupMessages(Number(group.id));
        if (response.success && response.data) {
          messages = response.data.map(mapApiGroupMessage);
          setLocalGroupMessages((currentMessages) => [
            ...currentMessages.filter((msg) => msg.groupId !== group.id),
            ...messages,
          ]);
        }
      }
    } catch {
      // Keep the local cache visible when the backend is unavailable.
    } finally {
      setHistoryMessages(sortHistoryMessages(messages.map((msg) => mapGroupHistoryMessage(msg, group))));
      setHistoryLoading(false);
    }
  };

  const handleRailSelect = (view: MainView) => {
    setMainView(view);
    setMobileContentOpen(false);
    if (view === 'messages') {
      void chatStore.loadContacts(false);
      void loadChatGroups();
    } else if (view === 'contacts') {
      void chatStore.loadContacts(false);
      void loadFriendRequests();
    } else {
      void loadFavorites();
    }
  };

  const updateContactGroup = (contact: Contact, groupName: string) => {
    const nextGroupName = normalizeContactGroupName(groupName) || DEFAULT_CONTACT_GROUP_NAME;
    setContactGroupNames((names) => mergeContactGroupNames([...names, nextGroupName], contactGroupAssignments));
    setContactGroupAssignments((groups) => ({
      ...groups,
      [String(contact.id)]: nextGroupName,
    }));
    setExpandedGroups((groups) => ({ ...groups, [nextGroupName]: true }));
    setContactManagerGroup((current) => (current === CONTACT_MANAGER_ALL_GROUP ? current : nextGroupName));
  };

  const handleCreateContactGroup = () => {
    const groupName = normalizeContactGroupName(contactGroupDraft);
    if (!groupName) {
      message.warning('请输入分组名称');
      return;
    }
    if (contactGroupNames.includes(groupName)) {
      message.warning('分组已存在');
      return;
    }

    setContactGroupNames((names) => [...names, groupName]);
    setExpandedGroups((groups) => ({ ...groups, [groupName]: true }));
    setContactManagerGroup(groupName);
    setContactGroupDraft('');
    setContactGroupCreateVisible(false);
    message.success('分组已添加');
  };

  const handleDeleteContactGroup = (groupName: string) => {
    if (groupName === DEFAULT_CONTACT_GROUP_NAME) {
      message.info('默认分组不能删除');
      return;
    }

    Modal.confirm({
      title: '删除分组',
      content: `删除“${groupName}”后，组内好友会移动到默认分组。`,
      okText: '删除',
      okButtonProps: { danger: true },
      cancelText: '取消',
      onOk: () => {
        setContactGroupNames((names) => names.filter((name) => name !== groupName));
        setContactGroupAssignments((assignments) => {
          const nextAssignments = { ...assignments };
          Object.entries(nextAssignments).forEach(([contactId, assignedGroup]) => {
            if (assignedGroup === groupName) {
              nextAssignments[contactId] = DEFAULT_CONTACT_GROUP_NAME;
            }
          });
          return nextAssignments;
        });
        setExpandedGroups((groups) => {
          const nextGroups = { ...groups };
          delete nextGroups[groupName];
          nextGroups[DEFAULT_CONTACT_GROUP_NAME] = true;
          return nextGroups;
        });
        setContactManagerGroup((current) => (current === groupName ? DEFAULT_CONTACT_GROUP_NAME : current));
        message.success('分组已删除');
      },
    });
  };

  const getGroupLatestMessage = (groupId: string) => {
    const messages = localGroupMessages.filter((msg) => msg.groupId === groupId);
    return messages[messages.length - 1];
  };

  const getGroupMessagePreview = (msg?: LocalGroupMessage) => {
    if (!msg) return '';
    const messageType = normalizeMessageType(msg.type);
    if (messageType === 'image') return '[图片]';
    if (messageType === 'audio') return `[语音] ${msg.duration || 1}"`;
    if (messageType === 'file') return `[文件] ${msg.content || '附件'}`;
    return msg.content;
  };

  const toggleActiveGroupPinned = () => {
    if (!activeGroup) return;
    const nextPinned = !activeGroup.pinned;
    setLocalGroups((groups) =>
      groups.map((group) =>
        group.id === activeGroup.id
          ? {
            ...group,
            pinned: nextPinned,
            category: nextPinned
              ? '置顶群聊'
              : group.ownerId === currentUserId
                ? '我创建的群聊'
                : '我加入的群聊',
          }
          : group
      )
    );
    message.success(nextPinned ? '已设为置顶' : '已取消置顶');
  };

  const toggleActiveGroupMuted = () => {
    if (!activeGroup) return;
    const nextMuted = !mutedGroupIds.includes(activeGroup.id);
    setMutedGroupIds((groupIds) =>
      nextMuted
        ? [...groupIds, activeGroup.id]
        : groupIds.filter((groupId) => groupId !== activeGroup.id)
    );
    message.success(nextMuted ? '已开启消息免打扰' : '已关闭消息免打扰');
  };

  const showComingSoon = (label: string) => {
    message.info(`${label} 正在接入中`);
  };

  const toggleCreateGroupMember = (userId?: number) => {
    if (typeof userId !== 'number') return;
    setSelectedGroupMemberIds((ids) =>
      ids.includes(userId) ? ids.filter((id) => id !== userId) : [...ids, userId]
    );
  };

  const createLocalGroup = async () => {
    const groupName = groupNameDraft.trim() || '未命名的群聊';
    const uniqueMemberIds = Array.from(new Set(selectedGroupMemberIds));

    if (uniqueMemberIds.length === 0) {
      message.warning('至少选择一个好友');
      return;
    }

    let group: LocalChatGroup;
    try {
      const response = await apiService.createChatGroup({
        name: groupName,
        category: groupCategoryDraft,
        member_ids: uniqueMemberIds,
        pinned: groupCategoryDraft === '置顶群聊',
      });

      if (!response.success || !response.data) {
        message.error(response.message || '创建群聊失败');
        return;
      }

      group = mapApiGroup(response.data);
    } catch (error: unknown) {
      message.warning(getErrorMessage(error, '后端不可用，已创建本地群聊'));
      group = {
        id: createLocalId('group'),
        name: groupName,
        category: groupCategoryDraft,
        memberIds: uniqueMemberIds,
        ownerId: currentUserId,
        createdAt: new Date().toISOString(),
      };
    }

    setLocalGroups((groups) => [group, ...groups]);
    setCreateGroupVisible(false);
    setGroupNameDraft('');
    setGroupCategoryDraft('我创建的群聊');
    setSelectedGroupMemberIds([]);

    if (shareVisible) {
      setSelectedShareTargetIds((ids) => Array.from(new Set([...ids, `group-${group.id}`])));
    } else {
      selectGroupForChat(group);
    }

    message.success('群聊已创建');
  };

  const selectGroupForChat = (group: LocalChatGroup) => {
    setMainView('messages');
    setActiveChatKind('group');
    setActiveGroupId(group.id);
    setEmojiOpen(false);
    setMobileContentOpen(true);
    chatStore.setCurrentContact(null);
    void loadGroupMessages(group.id);
  };

  const selectGroupProfile = (group: LocalChatGroup) => {
    setMainView('contacts');
    setContactPanel('groups');
    setContactContent('groupProfile');
    setActiveGroupId(group.id);
    setMobileContentOpen(true);
  };

  const selectContactForChat = (contact: Contact) => {
    setMainView('messages');
    setActiveChatKind('contact');
    setActiveGroupId('');
    setEmojiOpen(false);
    setProfileContact(contact);
    setMobileContentOpen(true);
    chatStore.setCurrentContact(contact);
  };

  const selectContactProfile = (contact: Contact) => {
    setMainView('contacts');
    setContactPanel('friends');
    setActiveChatKind('contact');
    setActiveGroupId('');
    setProfileContact(contact);
    setContactContent('profile');
    setMobileContentOpen(true);
  };

  const sendGroupMessage = async () => {
    if (!activeGroup) return;
    const content = groupMessageText.trim();
    if (!content) return;

    const sent = await sendGroupMessagePayload(activeGroup, {
      content,
      type: MESSAGE_TYPES.Text,
    });
    if (sent) {
      setGroupMessageText('');
      setEmojiOpen(false);
    }
  };

  const addFavoriteItem = async (item: Omit<FavoriteItem, 'id' | 'createdAt'>, stableId?: string) => {
    const id = stableId || createLocalId('favorite');
    const exists = favoriteItems.some(
      (favorite) =>
        favorite.id === id ||
        (favorite.type === item.type &&
          favorite.content === item.content &&
          favorite.sourceName === item.sourceName &&
          favorite.filePath === item.filePath)
    );

    if (exists) {
      message.info('已经收藏过了');
      return;
    }

    try {
      const response = await apiService.createFavorite({
        content: item.content,
        type: item.type,
        source_name: item.sourceName,
        file_path: item.filePath,
        file_size: item.fileSize,
      });

      if (response.success && response.data) {
        setFavoriteItems((items) => [mapApiFavorite(response.data!), ...items]);
        message.success(response.message || '已添加到收藏');
        return;
      }

      message.info(response.message || '已经收藏过了');
    } catch (error: unknown) {
      setFavoriteItems((items) => [
        {
          ...item,
          id,
          createdAt: new Date().toISOString(),
        },
        ...items,
      ]);
      message.warning(getErrorMessage(error, '后端不可用，已添加到本地收藏'));
    }
  };

  const addFavoriteFromMessage = async (msg: ChatMessage) => {
    const sourceName = isMessageFromCurrentUser(msg, currentUserId)
      ? currentUserName
      : getContactName(chatStore.currentContact);

    await addFavoriteItem(
      {
        content: msg.content,
        type: getFavoriteType(msg),
        sourceName,
        filePath: msg.file_path,
        fileSize: msg.file_size,
      },
      `chat-${msg.id}`
    );
  };

  const addFavoriteFromGroupMessage = async (msg: LocalGroupMessage) => {
    const messageType = normalizeMessageType(msg.type);

    await addFavoriteItem(
      {
        content: msg.content,
        type:
          messageType === 'image'
            ? 'media'
            : messageType === 'file'
              ? 'file'
              : getContentFavoriteType(msg.content),
        sourceName: `${activeGroup?.name || '群聊'} · ${msg.senderName}`,
        filePath: msg.filePath,
        fileSize: msg.fileSize,
      },
      `group-chat-${msg.id}`
    );
  };

  const addFavoriteNote = async () => {
    const content = favoriteNoteDraft.trim();
    if (!content) {
      message.warning('请输入笔记内容');
      return;
    }

    await addFavoriteItem({
      content,
      type: 'note',
      sourceName: currentUserName,
    });
    setFavoriteNoteDraft('');
    setFavoriteNoteVisible(false);
  };

  const removeFavoriteItem = async (favoriteId: string) => {
    if (isBackendId(favoriteId)) {
      try {
        const response = await apiService.deleteFavorite(Number(favoriteId));
        if (!response.success) {
          message.error(response.message || '删除收藏失败');
          return;
        }
      } catch (error: unknown) {
        message.error(getErrorMessage(error, '删除收藏失败'));
        return;
      }
    }

    setFavoriteItems((items) => items.filter((item) => item.id !== favoriteId));
  };

  const openShare = (payload: string) => {
    const content = payload.trim();
    if (!content) {
      message.warning('没有可分享的内容');
      return;
    }

    setShareMode('share');
    setSharePayload(content);
    setForwardPayload(null);
    setShareSearchText('');
    setShareNote('');
    setSelectedShareTargetIds([]);
    setShareVisible(true);
  };

  const openForward = (payload: ForwardMessagePayload) => {
    const content = payload.content.trim() || payload.preview.trim();
    if (!content) {
      message.warning('没有可转发的内容');
      return;
    }

    const nextPayload = {
      ...payload,
      content,
      preview: payload.preview.trim() || content,
    };
    setShareMode('forward');
    setSharePayload(nextPayload.preview);
    setForwardPayload(nextPayload);
    setShareSearchText('');
    setShareNote('');
    setSelectedShareTargetIds([]);
    setShareVisible(true);
  };

  const openForwardFromMessage = (msg: ChatMessage) => {
    const type = getMessageTypeValue(msg.type);
    const content = (msg.content || getForwardPreview({ content: '', type })).trim();
    openForward({
      content,
      type,
      file_path: msg.file_path,
      file_size: msg.file_size,
      duration: msg.duration,
      preview: getForwardPreview({ content, type, file_path: msg.file_path }),
    });
  };

  const openForwardFromGroupMessage = (msg: LocalGroupMessage) => {
    const type = getMessageTypeValue(msg.type);
    const content = (msg.content || getForwardPreview({ content: '', type })).trim();
    openForward({
      content,
      type,
      file_path: msg.filePath,
      file_size: msg.fileSize,
      duration: msg.duration,
      preview: getForwardPreview({ content, type, file_path: msg.filePath }),
    });
  };

  const toggleShareTarget = (targetId: string) => {
    setSelectedShareTargetIds((ids) =>
      ids.includes(targetId) ? ids.filter((id) => id !== targetId) : [...ids, targetId]
    );
  };

  const copyMessageContent = async (content: string) => {
    const nextContent = content.trim();
    if (!nextContent) {
      message.warning('没有可复制的内容');
      return;
    }

    try {
      if (!navigator.clipboard?.writeText) {
        message.error('当前浏览器不支持复制');
        return;
      }
      await navigator.clipboard.writeText(nextContent);
      message.success('已复制');
    } catch {
      message.error('复制失败');
    }
  };

  const handleNativeShare = async () => {
    if (!sharePayload.trim()) return;

    try {
      if (navigator.share) {
        await navigator.share({ text: sharePayload });
        return;
      }
      await navigator.clipboard?.writeText(sharePayload);
      message.success('内容已复制，可粘贴到微信');
    } catch {
      message.error('分享失败');
    }
  };

  const confirmShare = async () => {
    if (selectedShareTargets.length === 0) {
      message.warning(shareMode === 'forward' ? '请选择转发对象' : '请选择分享对象');
      return;
    }

    const note = shareNote.trim();
    const isForwarding = shareMode === 'forward' && forwardPayload;
    const content = isForwarding ? sharePayload : note ? `${sharePayload}\n\n${note}` : sharePayload;

    try {
      for (const target of selectedShareTargets) {
        if (target.type === 'contact') {
          const contactId = Number(target.id.replace('contact-', ''));
          const contact = chatStore.contacts.find((item) => item.id === contactId);
          const receiverId = contact?.contact_user?.id;
          if (contact && typeof receiverId === 'number') {
            if (isForwarding) {
              const sendOptions = {
                type: forwardPayload.type,
                file_path: forwardPayload.file_path,
                file_size: forwardPayload.file_size,
                duration: forwardPayload.duration,
              };
              const result =
                chatStore.currentContact?.id === contact.id
                  ? await chatStore.sendMessage(receiverId, forwardPayload.content, sendOptions)
                  : await apiService.sendMessage({
                    receiver_id: receiverId,
                    content: forwardPayload.content,
                    type: forwardPayload.type,
                    file_path: forwardPayload.file_path,
                    file_size: forwardPayload.file_size,
                    duration: forwardPayload.duration,
                  });
              if (!result.success) {
                message.error(result.message || '转发失败');
                return;
              }
              if (note) {
                if (chatStore.currentContact?.id === contact.id) {
                  await chatStore.sendMessage(receiverId, note);
                } else {
                  await apiService.sendMessage({ receiver_id: receiverId, content: note, type: MESSAGE_TYPES.Text });
                }
              }
            } else if (chatStore.currentContact?.id === contact.id) {
              await chatStore.sendMessage(receiverId, content);
            } else {
              await apiService.sendMessage({ receiver_id: receiverId, content, type: MESSAGE_TYPES.Text });
            }
          }
        } else {
          const groupId = target.id.replace('group-', '');
          const group = localGroups.find((item) => item.id === groupId);
          if (!group) {
            message.error('群聊不存在');
            return;
          }

          if (isForwarding) {
            const sent = await sendGroupMessagePayload(group, {
              content: forwardPayload.content,
              type: forwardPayload.type,
              file_path: forwardPayload.file_path,
              file_size: forwardPayload.file_size,
              duration: forwardPayload.duration,
            });
            if (!sent) return;
            if (note) {
              const noteSent = await sendGroupMessagePayload(group, {
                content: note,
                type: MESSAGE_TYPES.Text,
              });
              if (!noteSent) return;
            }
          } else {
            const sent = await sendGroupMessagePayload(group, {
              content,
              type: MESSAGE_TYPES.Text,
            });
            if (!sent) return;
          }
        }
      }

      await chatStore.loadContacts();
      await loadChatGroups();
      setShareVisible(false);
      setSelectedShareTargetIds([]);
      setShareNote('');
      setForwardPayload(null);
      setShareMode('share');
      message.success(isForwarding ? '已转发' : '已分享');
    } catch (error: unknown) {
      message.error(getErrorMessage(error, shareMode === 'forward' ? '转发失败' : '分享失败'));
    }
  };

  const toggleGroup = (key: string) => {
    setExpandedGroups((groups) => ({ ...groups, [key]: !groups[key] }));
  };

  const renderAvatar = (contact?: Contact | null, size: number = 44) => {
    const name = getContactName(contact);
    return (
      <span className={`avatar-shell ${contact?.contact_user?.is_online ? 'online' : 'offline'}`}>
        <Avatar size={size} src={getAvatarUrl(contact?.contact_user?.avatar_path)}>
          {getInitial(name)}
        </Avatar>
        {contact && <i aria-hidden="true" />}
      </span>
    );
  };

  const renderUserAvatar = (user?: UserSummary | null, size: number = 38) => {
    const name = getUserName(user);
    return (
      <span className={`avatar-shell ${user?.is_online ? 'online' : 'offline'}`}>
        <Avatar size={size} src={getAvatarUrl(user?.avatar_path)}>
          {getInitial(name)}
        </Avatar>
        {user && <i aria-hidden="true" />}
      </span>
    );
  };

  const renderAddContactUser = (user: UserSummary, source: string) => {
    const username = user.username || '';
    const normalizedUsername = normalizeUsername(username);
    const peerRequest = normalizedUsername ? friendRequestUsernameMap.get(normalizedUsername) : undefined;
    const requestStatus = peerRequest ? getFriendRequestStatus(peerRequest, currentUserId) : null;
    const incomingPending =
      peerRequest &&
      getFriendRequestDirection(peerRequest, currentUserId) === 'incoming' &&
      peerRequest.status === 'pending';
    const disabled = requestStatus === 'waiting' || requestStatus === 'accepted' || !username;
    const actionLabel = incomingPending
      ? '去处理'
      : requestStatus === 'waiting'
        ? '已申请'
        : requestStatus === 'accepted'
          ? '已添加'
          : requestStatus === 'rejected'
            ? '重新申请'
            : '添加';

    return (
      <div key={user.id || username} className="add-contact-user-card">
        {renderUserAvatar(user, 46)}
        <div className="add-contact-user-copy">
          <strong>{getUserName(user)}</strong>
          <span>@{username || 'unknown'}</span>
          <p>{user.signature?.trim() || '还没有填写个性签名'}</p>
          <div className="add-contact-user-tags">
            <em className={user.is_online ? 'status online' : 'status offline'}>
              {user.is_online ? '在线' : '离线'}
            </em>
            {(user.province || user.region) && <em>{[user.province, user.region].filter(Boolean).join('·')}</em>}
            {peerRequest && <em>{peerRequest.source || '账号搜索'}</em>}
          </div>
        </div>
        <Button
          className="add-contact-action"
          type={incomingPending ? 'primary' : 'default'}
          disabled={disabled}
          onClick={() => {
            if (incomingPending) {
              setAddContactVisible(false);
              setMainView('contacts');
              setContactPanel('friends');
              setContactContent('requests');
              return;
            }
            openAddContactRequest(username, source, user);
          }}
        >
          {actionLabel}
        </Button>
      </div>
    );
  };

  const renderMessage = (msg: ChatMessage, index: number, conversationMessages: ChatMessage[] = chatStore.messages) => {
    const isMine = isMessageFromCurrentUser(msg, currentUserId);
    const previous = conversationMessages[index - 1];
    const currentDate = formatHistoryDate(msg.created_at);
    const previousDate = previous ? formatHistoryDate(previous.created_at) : '';
    const showDate = index === 0 || currentDate !== previousDate;
    const attachmentUrl = getAttachmentUrl(msg.file_path);
    const shareContent = attachmentUrl ? `${msg.content || '附件'}\n${attachmentUrl}` : msg.content;
    const isMediaBubble = isImageMessage(msg) && Boolean(attachmentUrl);
    const contextMenu: MenuProps = {
      items: [
        {
          key: 'copy',
          icon: <CopyOutlined />,
          label: '复制',
          disabled: !shareContent.trim(),
        },
        {
          key: 'forward',
          icon: <ShareAltOutlined />,
          label: '转发',
        },
        {
          key: 'favorite',
          icon: <HeartOutlined />,
          label: '收藏',
        },
      ],
      onClick: ({ key }) => {
        if (key === 'copy') {
          void copyMessageContent(shareContent);
        }
        if (key === 'forward') openForwardFromMessage(msg);
        if (key === 'favorite') void addFavoriteFromMessage(msg);
      },
    };

    return (
      <div key={`${msg.id}-${index}`} className="message-block">
        {showDate && <div className="message-date">{formatDateLabel(msg.created_at)}</div>}
        <div className={`qq-message ${isMine ? 'sent' : 'received'}`}>
          {!isMine && renderAvatar(chatStore.currentContact, 36)}
          <Dropdown trigger={['contextMenu']} menu={contextMenu} overlayClassName="message-context-menu">
            <div className={`qq-bubble ${isMediaBubble ? 'media-bubble' : ''}`}>
              {isAudioMessage(msg) ? (
                <button
                  type="button"
                  className="voice-bubble voice-bubble-button"
                  disabled={!attachmentUrl}
                  onClick={() => {
                    if (!attachmentUrl) return;
                    void new Audio(attachmentUrl).play().catch(() => message.error('语音播放失败'));
                  }}
                >
                  <span className="voice-play" />
                  <span className="voice-bars" />
                  <span>{msg.duration || 4}&quot;</span>
                </button>
              ) : isImageMessage(msg) && attachmentUrl ? (
                <a className="message-image-link" href={attachmentUrl} target="_blank" rel="noreferrer">
                  <img className="message-image" src={attachmentUrl} alt={msg.content || '图片'} />
                </a>
              ) : isVideoMessage(msg) && attachmentUrl ? (
                <video className="message-video" src={attachmentUrl} controls playsInline />
              ) : isFileMessage(msg) && attachmentUrl ? (
                <a className="message-file-card" href={attachmentUrl} target="_blank" rel="noreferrer" download>
                  <FileOutlined />
                  <span>
                    <strong>{msg.content || '文件'}</strong>
                    <small>{formatFileSize(msg.file_size)}</small>
                  </span>
                </a>
              ) : (
                <div className="message-text">{msg.content}</div>
              )}
              <div className="message-meta">
                <span>{formatClock(msg.created_at)}</span>
                <button type="button" onClick={() => void addFavoriteFromMessage(msg)}>
                  收藏
                </button>
                <button type="button" onClick={() => openForwardFromMessage(msg)}>
                  转发
                </button>
              </div>
            </div>
          </Dropdown>
          {isMine && (
            <Avatar size={36} src={getAvatarUrl(authStore.user?.avatar_path)}>
              {getInitial(currentUserName)}
            </Avatar>
          )}
        </div>
      </div>
    );
  };

  const emojiKeyword = emojiSearchText.trim().toLowerCase();
  const filteredEmojiSections = emojiSections
    .map((section) => ({
      ...section,
      emojis: section.emojis.filter((emoji) => !emojiKeyword || section.title.toLowerCase().includes(emojiKeyword) || emoji.includes(emojiKeyword)),
    }))
    .filter((section) => section.emojis.length > 0);
  const activeGifCategory = gifStickerCategories.find((category) => category.key === gifCategory) || gifStickerCategories[0];
  const filteredGifStickers = gifStickers.filter((sticker) => {
    if (!emojiKeyword) return sticker.category === activeGifCategory.key;
    const stickerCategory = gifStickerCategories.find((category) => category.key === sticker.category);
    return [sticker.title, sticker.glyph, stickerCategory?.label || '', ...sticker.tags].some((text) =>
      text.toLowerCase().includes(emojiKeyword)
    );
  });
  const favoriteEmojis = emojiSections.slice(0, 2).flatMap((section) => section.emojis).slice(0, 32);

  const emojiContent = (
    <div className="emoji-panel">
      <div className="emoji-search-row">
        <Input
          prefix={<SearchOutlined />}
          value={emojiSearchText}
          onChange={(event) => setEmojiSearchText(event.target.value)}
          placeholder="搜索表情"
          allowClear
        />
      </div>
      <div className="emoji-chip-row">
        {emojiSearchChips.map((chip) => (
          <button
            type="button"
            key={chip}
            onClick={() => {
              setEmojiPanelMode('gif');
              setEmojiSearchText(chip);
            }}
          >
            {chip}
          </button>
        ))}
      </div>
      <div className="emoji-scroll">
        {emojiPanelMode === 'gif' ? (
          <>
            <div className="gif-category-row" role="tablist" aria-label="动态表情分类">
              {gifStickerCategories.map((category) => (
                <button
                  type="button"
                  key={category.key}
                  className={category.key === activeGifCategory.key && !emojiKeyword ? 'active' : ''}
                  onClick={() => {
                    setGifCategory(category.key);
                    setEmojiSearchText('');
                  }}
                  role="tab"
                  aria-selected={category.key === activeGifCategory.key && !emojiKeyword}
                >
                  <span>{category.icon}</span>
                  <strong>{category.label}</strong>
                  <small>
                    {category.available}
                    {category.total > category.available ? `/${category.total}` : ''}
                  </small>
                </button>
              ))}
            </div>
            <div className="gif-result-bar">
              {emojiKeyword
                ? `搜索结果 ${filteredGifStickers.length} 个`
                : `${activeGifCategory.label} ${activeGifCategory.available} 个`}
            </div>
            {filteredGifStickers.length === 0 ? (
              <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="没有找到 GIF" />
            ) : (
              <div className="gif-sticker-grid">
                {filteredGifStickers.map((sticker) => (
                  <button
                    type="button"
                    key={`${sticker.category}-${sticker.id}`}
                    className="gif-sticker-card"
                    onClick={() => void sendGifSticker(sticker)}
                  >
                    <span className="gif-sticker-preview">
                      <span className="gif-sticker-glyph" aria-hidden="true">
                        {sticker.glyph}
                      </span>
                      <img
                        src={sticker.src}
                        alt={sticker.title}
                        loading="lazy"
                        decoding="async"
                        referrerPolicy="no-referrer"
                        onError={(event) => {
                          event.currentTarget.classList.add('failed');
                          event.currentTarget.parentElement?.classList.add('image-failed');
                        }}
                      />
                    </span>
                    <span className="gif-sticker-label">{sticker.title}</span>
                  </button>
                ))}
              </div>
            )}
          </>
        ) : emojiPanelMode === 'favorite' ? (
          <div className="emoji-section">
            <div className="emoji-title">常用收藏</div>
            <div className="emoji-grid">
              {favoriteEmojis.map((emoji, index) => (
                <button
                  type="button"
                  key={`favorite-${emoji}-${index}`}
                  className="emoji-cell"
                  onClick={() => appendEmoji(emoji)}
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>
        ) : filteredEmojiSections.length === 0 ? (
          <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="没有找到表情" />
        ) : (
          filteredEmojiSections.map((section) => (
            <div key={section.title} className="emoji-section">
              <div className="emoji-title">{section.title}</div>
              <div className="emoji-grid">
                {section.emojis.map((emoji, index) => (
                  <button
                    type="button"
                    key={`${section.title}-${emoji}-${index}`}
                    className="emoji-cell"
                    onClick={() => appendEmoji(emoji)}
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            </div>
          ))
        )}
      </div>
      <div className="emoji-tabs">
        <button
          type="button"
          className={emojiPanelMode === 'emoji' ? 'active' : ''}
          onClick={() => setEmojiPanelMode('emoji')}
          aria-label="表情"
        >
          <SmileOutlined />
        </button>
        <button
          type="button"
          className={emojiPanelMode === 'favorite' ? 'active' : ''}
          onClick={() => setEmojiPanelMode('favorite')}
          aria-label="收藏"
        >
          <HeartOutlined />
        </button>
        <button
          type="button"
          className={emojiPanelMode === 'gif' ? 'active' : ''}
          onClick={() => setEmojiPanelMode('gif')}
        >
          GIF
        </button>
      </div>
    </div>
  );

  const renderSidebar = () => {
    if (mainView === 'messages') {
      const hasConversations = conversationRows.length > 0;

      return (
        <>
          <div className="sidebar-tools">
            <Input
              prefix={<SearchOutlined />}
              value={searchText}
              onChange={(event) => setSearchText(event.target.value)}
              placeholder="搜索"
              allowClear
            />
            <Tooltip title="添加好友">
              <Button icon={<PlusOutlined />} onClick={openAddContactDialog} />
            </Tooltip>
          </div>

          <div className="conversation-list">
            {!hasConversations ? (
              <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="暂无会话" />
            ) : (
              conversationRows.map((row) => {
                const content = (
                  <button
                    type="button"
                    key={row.id}
                    className={`conversation-item ${row.active ? 'active' : ''} ${row.pinned ? 'pinned' : ''}`}
                    onClick={() => (row.kind === 'contact' ? selectContactForChat(row.contact) : selectGroupForChat(row.group))}
                  >
                    <Badge count={row.muted ? 0 : row.unread} offset={[-4, 6]}>
                      {row.kind === 'contact' ? renderAvatar(row.contact) : <Avatar size={44} icon={<TeamOutlined />} />}
                    </Badge>
                    <span className="conversation-copy">
                      <span className="conversation-title-row">
                        <strong>{row.title}</strong>
                        <time>{row.time}</time>
                      </span>
                      <span className="conversation-preview-row">
                        <span className="conversation-preview">{row.preview}</span>
                        {(row.pinned || row.muted) && (
                          <span className="conversation-tags">
                            {row.pinned && <em>置顶</em>}
                            {row.muted && <em>免打扰</em>}
                          </span>
                        )}
                      </span>
                    </span>
                  </button>
                );

                return content;
              })
            )}
          </div>
        </>
      );
    }

    if (mainView === 'contacts') {
      return (
        <>
          <div className="sidebar-tools">
            <Input
              prefix={<SearchOutlined />}
              value={searchText}
              onChange={(event) => setSearchText(event.target.value)}
              placeholder="搜索"
              allowClear
            />
            <Tooltip title="添加好友">
              <Button icon={<PlusOutlined />} onClick={openAddContactDialog} />
            </Tooltip>
          </div>
          <Button className="friend-manager-button" icon={<UserAddOutlined />} onClick={openContactManager}>
            好友管理器
          </Button>
          <div className="notice-block">
            <button
              type="button"
              className={`notice-link ${contactContent === 'requests' ? 'active' : ''}`}
              onClick={() => {
                setContactPanel('friends');
                setContactContent('requests');
                setExpandedGroups((groups) => ({
                  ...groups,
                  friendNotice: !(groups.friendNotice ?? true),
                }));
              }}
              aria-expanded={expandedGroups.friendNotice}
            >
              <span>
                <BellOutlined /> 好友通知
              </span>
              <span className="notice-meta" aria-hidden="true">
                {pendingRequestCount > 0 && (
                  <em className="notice-count">{pendingRequestCount > 99 ? '99+' : pendingRequestCount}</em>
                )}
                <span className={expandedGroups.friendNotice ? 'group-arrow expanded' : 'group-arrow'} />
              </span>
            </button>
            {expandedGroups.friendNotice && (
              <div className="notice-sublist">
                {friendRequestSections.map((section) => (
                  <button
                    type="button"
                    key={section.key}
                    className={activeFriendRequestSection === section.key ? 'active' : ''}
                    onClick={() => {
                      setContactPanel('friends');
                      setContactContent('requests');
                      setActiveFriendRequestSection(section.key);
                      setExpandedGroups((groups) => ({
                        ...groups,
                        friendNotice: true,
                        [section.key]: true,
                      }));
                    }}
                  >
                    <span>{section.title}</span>
                    <em>{section.count}</em>
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="notice-block">
            <button
              type="button"
              className={`notice-link ${contactContent === 'groupNotices' ? 'active' : ''}`}
              onClick={() => {
                setContactContent('groupNotices');
              }}
            >
              <span>
                <TeamOutlined /> 群通知
              </span>
              <span className="notice-meta" aria-hidden="true">
                {pendingGroupNoticeCount > 0 && (
                  <em className="notice-count">{pendingGroupNoticeCount > 99 ? '99+' : pendingGroupNoticeCount}</em>
                )}
                <span className="group-arrow" />
              </span>
            </button>
          </div>
          <Segmented
            block
            className="contact-segment"
            value={contactPanel}
            onChange={(value) => setContactPanel(value as ContactPanel)}
            options={[
              { label: '好友', value: 'friends' },
              { label: '群聊', value: 'groups' },
            ]}
          />
          {contactPanel === 'friends' ? (
            <div className="friend-groups">
              {contactGroups.map((group) => (
                <div key={group.key} className="friend-group">
                  <button
                    type="button"
                    className={`friend-group-title ${
                      contactContent === 'profile' && profileContactGroupName === group.name ? 'active' : ''
                    }`}
                    onClick={() => toggleGroup(group.key)}
                  >
                    <span className={expandedGroups[group.key] ? 'group-arrow expanded' : 'group-arrow'} />
                    <strong>{group.name}</strong>
                    <span>{group.countText}</span>
                  </button>
                  {expandedGroups[group.key] && (
                    <div className="friend-group-list">
                      {group.contacts.length === 0 ? (
                        <div className="friend-empty-row">暂无好友</div>
                      ) : (
                        group.contacts.map((contact) => (
                          <button
                            type="button"
                            key={contact.id}
                            className={`friend-row ${profileContact?.id === contact.id ? 'active' : ''}`}
                            onClick={() => selectContactProfile(contact)}
                          >
                            {renderAvatar(contact, 42)}
                            <span>
                              <strong>{getContactName(contact)}</strong>
                              <small>
                                {contact.contact_user?.is_online ? '[在线]' : '[离线]'}{' '}
                                {contact.contact_user?.username || 'what can I say'}
                              </small>
                            </span>
                          </button>
                        ))
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="group-thread-panel">
              <Button
                className="create-group-button"
                type="primary"
                icon={<PlusOutlined />}
                onClick={() => setCreateGroupVisible(true)}
              >
                创建群聊
              </Button>
              <div className="group-thread-list">
                {localGroups.length === 0 ? (
                  <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="暂无群聊" />
                ) : (
                  groupCategories.map(({ category, groups }) => {
                    const groupKey = `local-group-${category}`;
                    const expanded = expandedGroups[groupKey] ?? true;
                    return (
                      <div key={category} className="friend-group">
                        <button type="button" className="friend-group-title" onClick={() => toggleGroup(groupKey)}>
                          <span className={expanded ? 'group-arrow expanded' : 'group-arrow'} />
                          <strong>{category}</strong>
                          <span>{groups.length}</span>
                        </button>
                        {expanded && (
                          <div className="friend-group-list">
                            {groups.length === 0 ? (
                              <div className="group-empty-row">暂无群聊</div>
                            ) : (
                              groups.map((group) => {
                                const latest = getGroupLatestMessage(group.id);
                                return (
	                                  <button
	                                    type="button"
	                                    key={group.id}
	                                    className={`group-thread ${activeGroupId === group.id ? 'active' : ''}`}
	                                    onClick={() => selectGroupProfile(group)}
	                                  >
	                                    <Avatar size={42} icon={<TeamOutlined />} />
	                                    <span>
	                                      <strong>{group.name}</strong>
	                                      <small>{latest ? getGroupMessagePreview(latest) : group.category}</small>
	                                    </span>
	                                    <em>{group.memberIds.length + 1}</em>
	                                  </button>
                                );
                              })
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          )}
        </>
      );
    }

    if (mainView === 'favorites') {
      const favoriteFilters: Array<{ key: FavoriteFilter; label: string }> = [
        { key: 'all', label: '全部' },
        { key: 'chat', label: '聊天记录' },
        { key: 'media', label: '图片与视频' },
        { key: 'file', label: '文件' },
        { key: 'link', label: '链接' },
        { key: 'note', label: '笔记' },
      ];

      return (
        <div className="favorite-sidebar">
          <div className="favorite-sidebar-search">
            <Input
              prefix={<SearchOutlined />}
              value={favoriteSearchText}
              onChange={(event) => setFavoriteSearchText(event.target.value)}
              placeholder="搜索收藏"
              allowClear
            />
          </div>
          <Button
            className="favorite-note-button"
            icon={<EditOutlined />}
            onClick={() => setFavoriteNoteVisible(true)}
          >
            创建笔记
          </Button>
          <div className="favorite-filter-list">
            {favoriteFilters.map((item) => (
              <button
                type="button"
                key={item.key}
                className={favoriteFilter === item.key ? 'active' : ''}
                onClick={() => setFavoriteFilter(item.key)}
              >
                <span>{item.label}</span>
                <em>{favoriteCounts[item.key]}</em>
              </button>
            ))}
          </div>
        </div>
      );
    }

    return null;
  };

  const renderContactMain = () => {
    if (contactContent === 'requests') {
      return (
        <div className="contact-main">
          <div className="contact-main-header">
            <h2>好友通知</h2>
            <Space>
              <Tooltip title="筛选">
                <Button type="text" icon={<FilterOutlined />} />
              </Tooltip>
              <Tooltip title="清理已处理">
                <Button
                  type="text"
                  icon={<DeleteOutlined />}
                  disabled={friendRequestsLoading}
                  onClick={() => void handleClearHandledRequests()}
                />
              </Tooltip>
            </Space>
          </div>

          {pendingRequestCount > 0 && (
            <div className="request-summary">
              <Badge status="processing" />
              <span>{pendingRequestCount} 条好友申请待处理</span>
            </div>
          )}

          <div className="request-list">
            {friendRequestsLoading ? (
              <div className="request-empty">加载中...</div>
            ) : (
              friendRequestSections.map((section) => {
                const expanded = expandedGroups[section.key] ?? true;
                return (
                  <section key={section.key} className="request-section">
                    <button
                      type="button"
                      className={`request-section-head ${activeFriendRequestSection === section.key ? 'active' : ''}`}
                      onClick={() => {
                        setActiveFriendRequestSection(section.key);
                        toggleGroup(section.key);
                      }}
                    >
                      <span className={expanded ? 'group-arrow expanded' : 'group-arrow'} />
                      <strong>{section.title}</strong>
                      <small>{section.description}</small>
                      <em>{section.count}</em>
                    </button>
                    {expanded && (
                      <div className="request-section-body">
                        {section.requests.length === 0 ? (
                          <div className="request-section-empty">{section.emptyText}</div>
                        ) : (
                          section.requests.map((request) => {
                            const peer = getFriendRequestPeer(request, currentUserId);
                            const requestDirection = getFriendRequestDirection(request, currentUserId);
                            if (!peer || !requestDirection) return null;

                            const peerName = getUserName(peer);
                            const requestStatus = getFriendRequestStatus(request, currentUserId);
                            return (
                              <div key={request.id} className="request-card">
                                <Avatar size={48} src={getAvatarUrl(peer.avatar_path)} icon={<UserOutlined />}>
                                  {getInitial(peerName)}
                                </Avatar>
                                <div className="request-copy">
                                  <div className="request-title">
                                    <strong>{peerName}</strong>
                                    <span>{getFriendRequestActionText(request, currentUserId)}</span>
                                    <time>{formatHistoryDate(request.created_at)}</time>
                                  </div>
                                  <p>留言：{request.note || '请求添加为好友'}</p>
                                  <p>来源：{request.source || '账号搜索'}</p>
                                </div>
                                {requestStatus === 'pending' && requestDirection === 'incoming' ? (
                                  <Space>
                                    <Button
                                      icon={<CheckOutlined />}
                                      type="primary"
                                      onClick={() => void handleFriendRequest(request, 'accepted')}
                                    >
                                      同意
                                    </Button>
                                    <Button icon={<StopOutlined />} onClick={() => void handleFriendRequest(request, 'rejected')}>
                                      拒绝
                                    </Button>
                                  </Space>
                                ) : (
                                  <span className={`request-status ${requestStatus}`}>
                                    {requestStatus === 'accepted' && '已同意'}
                                    {requestStatus === 'rejected' && '已拒绝'}
                                    {requestStatus === 'waiting' && '等待验证'}
                                  </span>
                                )}
                              </div>
                            );
                          })
                        )}
                      </div>
                    )}
                  </section>
                );
              })
            )}
          </div>
        </div>
      );
    }

    if (contactContent === 'groupNotices') {
      const currentGroupNoticeSection =
        groupNoticeSections.find((section) => section.key === activeGroupNoticeSection) || groupNoticeSections[0];

      return (
        <div className="contact-main group-notice-main">
          <div className="contact-main-header">
            <h2>群通知</h2>
            <Space>
              <Tooltip title="筛选">
                <Button type="text" icon={<FilterOutlined />} disabled={totalGroupNoticeCount === 0} />
              </Tooltip>
              <Tooltip title="清理已处理">
                <Button type="text" icon={<DeleteOutlined />} disabled={totalGroupNoticeCount === 0} />
              </Tooltip>
            </Space>
          </div>

          <div className="group-notice-strip">
            {groupNoticeSections.map((section) => (
              <button
                type="button"
                key={section.key}
                className={activeGroupNoticeSection === section.key ? 'active' : ''}
                onClick={() => {
                  setActiveGroupNoticeSection(section.key);
                }}
              >
                <span>{section.title}</span>
                <em>{section.count}</em>
              </button>
            ))}
          </div>

          <div className="group-notice-empty-state">
            <span className="group-notice-empty-icon">
              <BellOutlined />
            </span>
            <strong>{currentGroupNoticeSection?.count ? currentGroupNoticeSection.title : '暂无群通知'}</strong>
            <div className="group-notice-actions">
              <Button
                icon={<TeamOutlined />}
                disabled={localGroups.length === 0}
                onClick={() => {
                  if (localGroups[0]) {
                    selectGroupProfile(localGroups[0]);
                  }
                }}
              >
                查看群聊
              </Button>
              <Button type="primary" icon={<PlusOutlined />} onClick={() => setCreateGroupVisible(true)}>
                创建群聊
              </Button>
            </div>
          </div>
        </div>
      );
    }

    if (contactContent === 'groupProfile' && activeGroup) {
      return (
        <div className="contact-main qq-group-profile-main">
          <div className="qq-group-profile">
            <section className="qq-group-profile-hero">
              <Avatar size={82} icon={<TeamOutlined />} />
              <div>
                <h2>{activeGroup.name}</h2>
                <p>群号 {activeGroup.id} · {activeGroup.category}</p>
                <span>群主 {activeGroupOwnerName} · {formatHistoryDate(activeGroup.createdAt)} 创建</span>
              </div>
              <Space>
                <Button icon={<ShareAltOutlined />} onClick={() => openShare(`群聊名片：${activeGroup.name}（${allGroupMembers.length}人）`)}>
                  分享
                </Button>
                <Button type="primary" icon={<MessageOutlined />} onClick={() => selectGroupForChat(activeGroup)}>
                  发消息
                </Button>
              </Space>
            </section>

            <section className="qq-group-profile-section">
              <div className="qq-group-section-head">
                <strong>群聊成员</strong>
                <button type="button" onClick={() => showComingSoon('完整成员管理')}>
                  查看{allGroupMembers.length}名群成员
                </button>
              </div>
              <div className="qq-group-profile-member-grid">
                {activeGroupMemberPreview.map((member) => (
                  <button type="button" key={member.id || member.username} onClick={() => showComingSoon('成员资料')}>
                    {renderUserAvatar(member, 38)}
                    <span>{getUserName(member)}</span>
                  </button>
                ))}
                <button type="button" className="qq-group-member-action" onClick={() => setCreateGroupVisible(true)}>
                  <PlusOutlined />
                  <span>邀请</span>
                </button>
                <button type="button" className="qq-group-member-action" onClick={() => showComingSoon('移出群成员')}>
                  <StopOutlined />
                  <span>移出</span>
                </button>
              </div>
            </section>

            <section className="qq-group-profile-section">
              <div className="qq-group-section-head">
                <strong>资料管理</strong>
              </div>
              <button type="button" className="qq-profile-nav-row" onClick={() => showComingSoon('群资料设置')}>
                <span>
                  <SettingOutlined /> 群资料设置
                </span>
                <em>{activeGroup.ownerId === currentUserId ? '我创建的群聊' : '我加入的群聊'}</em>
              </button>
              <button type="button" className="qq-profile-nav-row" onClick={() => showComingSoon('群公告编辑')}>
                <span>
                  <BellOutlined /> 群公告
                </span>
                <em>{activeGroup.announcement || '暂无公告'}</em>
              </button>
              <label className="qq-profile-input-row">
                <span>我在本群昵称</span>
                <input value={currentUserName} readOnly />
              </label>
              <label className="qq-profile-input-row">
                <span>群聊备注</span>
                <input value={activeGroup.note || ''} readOnly placeholder="填写备注" />
              </label>
            </section>

            <section className="qq-group-profile-section">
              <div className="qq-group-section-head">
                <strong>群消息设置</strong>
              </div>
              <button type="button" className="qq-profile-switch-row" onClick={toggleActiveGroupPinned}>
                <span>设为置顶</span>
                <i className={activeGroup.pinned ? 'on' : ''} />
              </button>
              <button type="button" className="qq-profile-switch-row" onClick={toggleActiveGroupMuted}>
                <span>消息免打扰</span>
                <i className={activeGroupMuted ? 'on' : ''} />
              </button>
              <button type="button" className="qq-profile-nav-row" onClick={() => void openGroupHistory()}>
                <span>接收消息但不提醒</span>
                <em>{activeGroupMuted ? '已开启' : '未开启'}</em>
              </button>
            </section>

            <section className="qq-group-profile-danger">
              <button type="button" onClick={() => showComingSoon('删除聊天记录')}>删除聊天记录</button>
              <button type="button" onClick={() => showComingSoon('退出群聊')}>退出群聊</button>
              <button type="button" onClick={() => showComingSoon('举报该群')}>被骚扰了？举报该群</button>
            </section>
          </div>
        </div>
      );
    }

    if (!profileContact) {
      return (
        <div className="empty-chat">
          <UserOutlined />
          <p>选择一个好友查看资料</p>
        </div>
      );
    }

    const profileUser = profileContact.contact_user as UserSummary;
    const profileFields = [
      profileUser?.gender || '性别未填',
      formatAge(profileUser?.birthday),
      formatBirthdayLabel(profileUser?.birthday),
      formatLocation(profileUser),
    ];

    return (
      <div className="contact-main contact-profile-main">
        <div className="profile-panel">
          <div className="profile-identity">
            {renderAvatar(profileContact, 96)}
            <div>
              <h2>{getContactName(profileContact)}</h2>
              <p>@{profileUser?.username || 'unknown'} · ID {profileUser?.id || profileContact.id}</p>
              <span className={`online-state ${profileUser?.is_online ? 'online' : 'offline'}`}>
                <i /> {profileUser?.is_online ? '在线' : '离线'}
              </span>
            </div>
            <div className="profile-like">
              <ClockCircleOutlined />
              <span>{formatHistoryDate(profileContact.added_at)}</span>
            </div>
          </div>
          <div className="profile-fields">
            {profileFields.map((field) => (
              <span key={field}>{field}</span>
            ))}
          </div>
          <div className="profile-row">
            <span>
              <EditOutlined /> 备注
            </span>
            <strong>{profileContact.display_name || '未设置'}</strong>
          </div>
          <div className="profile-row">
            <span>
              <TeamOutlined /> 好友分组
            </span>
            <select
              className="profile-group-select"
              value={profileContactGroupName}
              onChange={(event) => updateContactGroup(profileContact, event.target.value)}
            >
              {contactGroupNames.map((groupName) => (
                <option key={groupName} value={groupName}>
                  {groupName}
                </option>
              ))}
            </select>
          </div>
          <div className="profile-row">
            <span>
              <EditOutlined /> 签名
            </span>
            <strong>{getContactSignature(profileContact)}</strong>
          </div>
          <div className="profile-actions">
            <Button
              onClick={() =>
                openShare(`联系人名片：${getContactName(profileContact)}（@${profileUser?.username || 'unknown'}）`)
              }
            >
              分享
            </Button>
            <Button
              icon={<PhoneOutlined />}
              onClick={() => {
                selectContactForChat(profileContact);
                void handleInitiateCall(CallType.Voice, profileContact);
              }}
            >
              语音
            </Button>
            <Button
              icon={<VideoCameraOutlined />}
              onClick={() => {
                selectContactForChat(profileContact);
                void handleInitiateCall(CallType.Video, profileContact);
              }}
            >
              视频
            </Button>
            <Button type="primary" onClick={() => selectContactForChat(profileContact)}>
              发消息
            </Button>
          </div>
        </div>
      </div>
    );
  };

  const renderFavoriteMain = () => {
    const favoriteTypeText: Record<FavoriteItem['type'], string> = {
      chat: '聊天记录',
      media: '图片与视频',
      file: '文件',
      link: '链接',
      note: '笔记',
    };

    return (
      <div className="favorites-main">
        <div className="favorites-header">
          <div>
            <h2>我的收藏</h2>
            <p>{favoriteCounts.all} 条内容</p>
          </div>
          <Button type="primary" icon={<EditOutlined />} onClick={() => setFavoriteNoteVisible(true)}>
            创建笔记
          </Button>
        </div>

        <div className="favorites-list">
          {filteredFavoriteItems.length === 0 ? (
            <div className="favorites-empty">
              <HeartOutlined />
              <span>暂无收藏内容</span>
            </div>
          ) : (
            filteredFavoriteItems.map((item) => {
              const attachmentUrl = getAttachmentUrl(item.filePath);
              const shareContent = attachmentUrl ? `${item.content}\n${attachmentUrl}` : item.content;

              return (
                <article key={item.id} className="favorite-card">
                  <div className="favorite-card-head">
                    <span>{favoriteTypeText[item.type]}</span>
                    <time>{formatHistoryDate(item.createdAt)} {formatClock(item.createdAt)}</time>
                  </div>
                  <div className="favorite-card-body">
                    {item.type === 'media' && attachmentUrl ? (
                      <a href={attachmentUrl} target="_blank" rel="noreferrer">
                        <img src={attachmentUrl} alt={item.content || '收藏图片'} />
                      </a>
                    ) : item.type === 'file' && attachmentUrl ? (
                      <a className="favorite-file" href={attachmentUrl} target="_blank" rel="noreferrer" download>
                        <FileOutlined />
                        <span>
                          <strong>{item.content || '文件'}</strong>
                          <small>{formatFileSize(item.fileSize)}</small>
                        </span>
                      </a>
                    ) : (
                      <p>{item.content}</p>
                    )}
                  </div>
                  <div className="favorite-card-foot">
                    <span>来自 {item.sourceName}</span>
                    <Space size={6}>
                      <Button size="small" icon={<ShareAltOutlined />} onClick={() => openShare(shareContent)}>
                        分享
                      </Button>
                      <Button size="small" icon={<DeleteOutlined />} onClick={() => void removeFavoriteItem(item.id)}>
                        删除
                      </Button>
                    </Space>
                  </div>
                </article>
              );
            })
          )}
        </div>
      </div>
    );
  };

  const renderGroupMessage = (msg: LocalGroupMessage, index: number) => {
    const isMine = msg.senderId === currentUserId;
    const previous = activeGroupMessages[index - 1];
    const currentDate = formatHistoryDate(msg.createdAt);
    const previousDate = previous ? formatHistoryDate(previous.createdAt) : '';
    const showDate = index === 0 || currentDate !== previousDate;
    const messageType = normalizeMessageType(msg.type);
    const attachmentUrl = getAttachmentUrl(msg.filePath);
    const shareContent = attachmentUrl ? `${msg.content || '附件'}\n${attachmentUrl}` : msg.content;
    const isMediaBubble = messageType === 'image' && Boolean(attachmentUrl);
    const sender = isMine
      ? (authStore.user as UserSummary | null)
      : (chatStore.contacts.find((contact) => contact.contact_user?.id === msg.senderId)?.contact_user as UserSummary | undefined);
    const contextMenu: MenuProps = {
      items: [
        {
          key: 'copy',
          icon: <CopyOutlined />,
          label: '复制',
          disabled: !shareContent.trim(),
        },
        {
          key: 'forward',
          icon: <ShareAltOutlined />,
          label: '转发',
        },
        {
          key: 'favorite',
          icon: <HeartOutlined />,
          label: '收藏',
        },
      ],
      onClick: ({ key }) => {
        if (key === 'copy') {
          void copyMessageContent(shareContent);
        }
        if (key === 'forward') openForwardFromGroupMessage(msg);
        if (key === 'favorite') void addFavoriteFromGroupMessage(msg);
      },
    };

    return (
      <div key={msg.id} className="message-block">
        {showDate && <div className="message-date">{formatDateLabel(msg.createdAt)}</div>}
        <div className={`qq-message ${isMine ? 'sent' : 'received'}`}>
          {!isMine && renderUserAvatar(sender, 36)}
          <Dropdown trigger={['contextMenu']} menu={contextMenu} overlayClassName="message-context-menu">
            <div className={`qq-bubble ${isMediaBubble ? 'media-bubble' : ''}`}>
              {!isMine && <div className="group-message-sender">{msg.senderName}</div>}
              {messageType === 'audio' ? (
                <button
                  type="button"
                  className="voice-bubble voice-bubble-button"
                  disabled={!attachmentUrl}
                  onClick={() => {
                    if (!attachmentUrl) return;
                    void new Audio(attachmentUrl).play().catch(() => message.error('语音播放失败'));
                  }}
                >
                  <span className="voice-play" />
                  <span className="voice-bars" />
                  <span>{msg.duration || 4}&quot;</span>
                </button>
              ) : messageType === 'image' && attachmentUrl ? (
                <a className="message-image-link" href={attachmentUrl} target="_blank" rel="noreferrer">
                  <img className="message-image" src={attachmentUrl} alt={msg.content || '图片'} />
                </a>
              ) : messageType === 'video' && attachmentUrl ? (
                <video className="message-video" src={attachmentUrl} controls playsInline />
              ) : messageType === 'file' && attachmentUrl ? (
                <a className="message-file-card" href={attachmentUrl} target="_blank" rel="noreferrer" download>
                  <FileOutlined />
                  <span>
                    <strong>{msg.content || '文件'}</strong>
                    <small>{formatFileSize(msg.fileSize)}</small>
                  </span>
                </a>
              ) : (
                <div className="message-text">{msg.content}</div>
              )}
              <div className="message-meta">
                <span>{formatClock(msg.createdAt)}</span>
                <button type="button" onClick={() => void addFavoriteFromGroupMessage(msg)}>
                  收藏
                </button>
                <button type="button" onClick={() => openForwardFromGroupMessage(msg)}>
                  转发
                </button>
              </div>
            </div>
          </Dropdown>
          {isMine && renderUserAvatar(authStore.user as UserSummary, 36)}
        </div>
      </div>
    );
  };

  const renderGroupChatMain = () => {
    if (!activeGroup) {
      return (
        <div className="empty-chat">
          <TeamOutlined />
          <p>选择一个群聊开始聊天</p>
        </div>
      );
    }

    const groupMoreItems: MenuProps['items'] = [
      { key: 'history', icon: <ClockCircleOutlined />, label: '聊天记录' },
      { key: 'profile', icon: <TeamOutlined />, label: '群资料' },
      { key: 'pin', icon: <BellOutlined />, label: activeGroup.pinned ? '取消置顶' : '设为置顶' },
      { key: 'mute', icon: <StopOutlined />, label: activeGroupMuted ? '关闭免打扰' : '消息免打扰' },
      { key: 'share', icon: <ShareAltOutlined />, label: '分享群聊' },
    ];
    const handleGroupMoreClick: MenuProps['onClick'] = ({ key }) => {
      if (key === 'history') void openGroupHistory();
      if (key === 'profile') selectGroupProfile(activeGroup);
      if (key === 'pin') toggleActiveGroupPinned();
      if (key === 'mute') toggleActiveGroupMuted();
      if (key === 'share') openShare(`群聊名片：${activeGroup.name}（${allGroupMembers.length}人）`);
    };

    return (
      <div className="group-chat-panel">
        <div className="chat-header">
          <Button
            type="text"
            className="mobile-back-button"
            icon={<ArrowLeftOutlined />}
            onClick={() => setMobileContentOpen(false)}
          />
          <div className="chat-title">
            <strong>{activeGroup.name}</strong>
            <small>{activeGroup.memberIds.length + 1}人</small>
          </div>
          <Space size={8}>
            <Tooltip title="语音通话">
              <Button type="text" icon={<PhoneOutlined />} onClick={() => showComingSoon('群语音通话')} />
            </Tooltip>
            <Tooltip title="视频通话">
              <Button type="text" icon={<VideoCameraOutlined />} onClick={() => showComingSoon('群视频通话')} />
            </Tooltip>
            <Tooltip title="屏幕共享">
              <Button type="text" icon={<DesktopOutlined />} onClick={() => void handleScreenRecording()} />
            </Tooltip>
            <Tooltip title="群应用">
              <Button type="text" icon={<AppstoreOutlined />} onClick={() => showComingSoon('群应用')} />
            </Tooltip>
            <Tooltip title="邀请加群">
              <Button type="text" icon={<PlusOutlined />} onClick={() => setCreateGroupVisible(true)} />
            </Tooltip>
            <Dropdown menu={{ items: groupMoreItems, onClick: handleGroupMoreClick }} trigger={['click']}>
              <Button type="text" icon={<MoreOutlined />} />
            </Dropdown>
          </Space>
        </div>
        <div className="group-chat-content">
          <section className="group-message-column">
            <div className="messages-container">
              {activeGroupMessages.length === 0 ? (
                <div className="empty-messages">
                  <div className="qq-watermark" />
                  <span>暂无群聊记录</span>
                </div>
              ) : (
                activeGroupMessages.map(renderGroupMessage)
              )}
              <div ref={messagesEndRef} />
            </div>
            <div className="composer">
              <div className="composer-toolbar">
	                <Popover
	                  trigger="click"
	                  placement="topLeft"
	                  open={emojiOpen}
	                  onOpenChange={setEmojiOpen}
	                  content={emojiContent}
	                  classNames={{ root: 'emoji-popover' }}
	                >
                  <Button type="text" icon={<SmileOutlined />} />
                </Popover>
                {renderScreenshotToolButton()}
                <Tooltip title="发送文件">
                  <Button
                    type="text"
                    icon={<FolderOpenOutlined />}
                    loading={attachmentUploading}
                    onClick={() => fileInputRef.current?.click()}
                  />
                </Tooltip>
                <Tooltip title="图片">
                  <Button
                    type="text"
                    icon={<PictureOutlined />}
                    loading={attachmentUploading}
                    onClick={() => imageInputRef.current?.click()}
                  />
                </Tooltip>
                <Tooltip title="语音">
                  <Button
                    type="text"
                    icon={<AudioOutlined />}
                    danger={isRecordingVoice}
                    loading={attachmentUploading && !isRecordingVoice}
                    onClick={() => void handleVoiceButtonClick()}
                  />
                </Tooltip>
                <Tooltip title="红包">
                  <Button type="text" icon={<GiftOutlined />} onClick={() => showComingSoon('红包')} />
                </Tooltip>
                <Tooltip title="收藏笔记">
                  <Button type="text" icon={<HeartOutlined />} onClick={() => setFavoriteNoteVisible(true)} />
                </Tooltip>
                <Tooltip title="分享">
                  <Button type="text" icon={<ShareAltOutlined />} onClick={() => openShare(groupMessageText || activeGroup.name)} />
                </Tooltip>
                <input
                  ref={fileInputRef}
                  className="composer-file-input"
                  type="file"
                  onChange={(event) => void handleAttachmentSelect(event, MESSAGE_TYPES.File)}
                />
                <input
                  ref={imageInputRef}
                  className="composer-file-input"
                  type="file"
                  accept="image/*"
                  onChange={(event) => void handleAttachmentSelect(event, MESSAGE_TYPES.Image)}
                />
              </div>
              {isRecordingVoice && (
                <div className="voice-recording-strip">
                  <span className="voice-recording-pulse" />
                  <span>正在录音 {voiceRecordSeconds || 1}&quot;</span>
                  <Button size="small" type="primary" onClick={() => void handleVoiceButtonClick()}>
                    停止并发送
                  </Button>
                </div>
              )}
              <div className="composer-input">
                <TextArea
                  value={groupMessageText}
                  onChange={(event) => setGroupMessageText(event.target.value)}
                  onPaste={(event) => void handleComposerPaste(event)}
                  onPressEnter={(event) => {
                    if (!event.shiftKey) {
                      event.preventDefault();
                      void sendGroupMessage();
                    }
                  }}
                  autoSize={{ minRows: 2, maxRows: 5 }}
                />
                <Button type="primary" icon={<SendOutlined />} onClick={() => void sendGroupMessage()} disabled={!groupMessageText.trim()}>
                  发送
                </Button>
              </div>
            </div>
          </section>
          <aside className="group-detail-panel">
            <button type="button" className="group-announcement-card" onClick={() => selectGroupProfile(activeGroup)}>
              <span>
                <BellOutlined /> 群公告
              </span>
              <p>{activeGroup.announcement || '暂无公告'}</p>
            </button>
            <section className="group-side-section">
              <div className="group-side-head">
                <strong>群聊成员</strong>
                <span>{allGroupMembers.length}</span>
              </div>
              <button type="button" className="group-side-search" onClick={() => showComingSoon('搜索群成员')}>
                <SearchOutlined /> 搜索群成员
              </button>
              <div className="group-side-member-grid">
                {activeGroupMemberPreview.map((member) => (
                  <button type="button" key={member.id || member.username} onClick={() => showComingSoon('成员资料')}>
                    {renderUserAvatar(member, 32)}
                    <span>{getUserName(member)}</span>
                  </button>
                ))}
                <button type="button" className="group-side-member-action" onClick={() => setCreateGroupVisible(true)}>
                  <PlusOutlined />
                  <span>邀请</span>
                </button>
              </div>
            </section>
            <section className="group-side-section">
              <div className="group-side-head">
                <strong>资料管理</strong>
              </div>
              <button type="button" className="group-side-row" onClick={() => selectGroupProfile(activeGroup)}>
                <span>群资料设置</span>
                <em>{activeGroup.category}</em>
              </button>
              <button type="button" className="group-side-row" onClick={toggleActiveGroupPinned}>
                <span>设为置顶</span>
                <i className={activeGroup.pinned ? 'on' : ''} />
              </button>
              <button type="button" className="group-side-row" onClick={toggleActiveGroupMuted}>
                <span>消息免打扰</span>
                <i className={activeGroupMuted ? 'on' : ''} />
              </button>
              <button type="button" className="group-side-row" onClick={() => void openGroupHistory()}>
                <span>聊天记录</span>
                <em>查看</em>
              </button>
            </section>
          </aside>
        </div>
      </div>
    );
  };

  const renderChatMain = () => {
    if (activeChatKind === 'group') {
      return renderGroupChatMain();
    }

    const contact = chatStore.currentContact;
    if (!contact) {
      return (
        <div className="empty-chat">
          <MessageOutlined />
          <p>选择一个会话开始聊天</p>
        </div>
      );
    }
    const contactMessages = chatStore.messages.filter((msg) =>
      isMessageInContactConversation(msg, currentUserId, contact.contact_user?.id)
    );

    return (
      <div className="chat-panel">
        <div className="chat-header">
          <Button
            type="text"
            className="mobile-back-button"
            icon={<ArrowLeftOutlined />}
            onClick={() => setMobileContentOpen(false)}
          />
          <div className="chat-title">
            <strong>{getContactName(contact)}</strong>
            {contact.contact_user?.is_online && <span />}
          </div>
          <Space size={8}>
            <Tooltip title="语音通话">
              <Button type="text" icon={<PhoneOutlined />} onClick={() => void handleInitiateCall(CallType.Voice)} />
            </Tooltip>
            <Tooltip title="视频通话">
              <Button type="text" icon={<VideoCameraOutlined />} onClick={() => void handleInitiateCall(CallType.Video)} />
            </Tooltip>
            <Tooltip title="聊天记录">
              <Button type="text" icon={<FolderOpenOutlined />} onClick={() => void openHistory()} />
            </Tooltip>
            <Tooltip title="添加">
              <Button type="text" icon={<PlusOutlined />} onClick={openAddContactDialog} />
            </Tooltip>
            <Dropdown menu={{ items: contactMenuItems }} trigger={['click']}>
              <Button type="text" icon={<MoreOutlined />} />
            </Dropdown>
          </Space>
        </div>
        <div className="messages-container">
          {contactMessages.length === 0 ? (
            <div className="empty-messages">
              <div className="qq-watermark" />
              <span>暂无聊天记录</span>
            </div>
          ) : (
            contactMessages.map(renderMessage)
          )}
          <div ref={messagesEndRef} />
        </div>
        <div className="composer">
          <div className="composer-toolbar">
            <Popover
              trigger="click"
              placement="topLeft"
              open={emojiOpen}
              onOpenChange={setEmojiOpen}
              content={emojiContent}
              classNames={{ root: 'emoji-popover' }}
            >
              <Button type="text" icon={<SmileOutlined />} />
            </Popover>
            {renderScreenshotToolButton()}
            <Tooltip title="发送文件">
              <Button
                type="text"
                icon={<FolderOpenOutlined />}
                loading={attachmentUploading}
                onClick={() => fileInputRef.current?.click()}
              />
            </Tooltip>
            <Tooltip title="图片">
              <Button
                type="text"
                icon={<PictureOutlined />}
                loading={attachmentUploading}
                onClick={() => imageInputRef.current?.click()}
              />
            </Tooltip>
            <Tooltip title="语音">
              <Button
                type="text"
                icon={<AudioOutlined />}
                danger={isRecordingVoice}
                loading={attachmentUploading && !isRecordingVoice}
                onClick={() => void handleVoiceButtonClick()}
              />
            </Tooltip>
            <Tooltip title="历史记录">
              <Button type="text" icon={<ClockCircleOutlined />} className="history-shortcut" onClick={() => void openHistory()} />
            </Tooltip>
            <input
              ref={fileInputRef}
              className="composer-file-input"
              type="file"
              onChange={(event) => void handleAttachmentSelect(event, MESSAGE_TYPES.File)}
            />
            <input
              ref={imageInputRef}
              className="composer-file-input"
              type="file"
              accept="image/*"
              onChange={(event) => void handleAttachmentSelect(event, MESSAGE_TYPES.Image)}
            />
          </div>
          {isRecordingVoice && (
            <div className="voice-recording-strip">
              <span className="voice-recording-pulse" />
              <span>正在录音 {voiceRecordSeconds || 1}&quot;</span>
              <Button size="small" type="primary" onClick={() => void handleVoiceButtonClick()}>
                停止并发送
              </Button>
            </div>
          )}
          <div className="composer-input">
            <TextArea
              value={messageText}
              onChange={(event) => setMessageText(event.target.value)}
              onPaste={(event) => void handleComposerPaste(event)}
              onPressEnter={(event) => {
                if (!event.shiftKey) {
                  event.preventDefault();
                  void handleSendMessage();
                }
              }}
              placeholder=""
              autoSize={{ minRows: 2, maxRows: 5 }}
            />
            <Button type="primary" icon={<SendOutlined />} onClick={() => void handleSendMessage()} disabled={!messageText.trim()}>
              发送
            </Button>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className={`qq-app ${mobileContentOpen ? 'mobile-content-open' : ''}`}>
      <div className="qq-window">
        <div className="qq-titlebar">
          <button
            type="button"
            className="profile-avatar-button"
            onClick={openProfileSettings}
            title="编辑资料"
            aria-label="编辑资料"
          >
            <Avatar size={28} src={getAvatarUrl(authStore.user?.avatar_path)}>
              {getInitial(currentUserName)}
            </Avatar>
          </button>
          <div className="account-copy">
            <button
              type="button"
              className="profile-name-button"
              onClick={openProfileSettings}
              title="编辑资料"
            >
              {currentUserName}
            </button>
            <button type="button" className="signature-button" onClick={openSignatureEditor} title="编辑个性签名">
              {currentSignature}
            </button>
          </div>
          <div className="title-actions">
            <Tooltip
              title={`${weather.location}${weather.updatedAt ? ` · ${weather.updatedAt}` : ''}`}
            >
              <span className="weather-pill">
                <CloudOutlined />
                <span>
                  {weather.label}
                  {typeof weather.temperature === 'number' ? ` ${weather.temperature}°` : ''}
                </span>
              </span>
            </Tooltip>
            <Button type="text" icon={<LogoutOutlined />} onClick={handleLogout} />
          </div>
        </div>

        <div className="qq-body">
          <nav className="qq-rail">
            <div className="rail-top">
              {railItems.map((item) => (
                <Tooltip title={item.label} placement="right" key={item.key}>
                  <button
                    type="button"
                    className={`rail-button ${mainView === item.key ? 'active' : ''}`}
                    onClick={() => handleRailSelect(item.key)}
                    aria-label={item.label}
                  >
                    <Badge count={item.badge || 0} size="small" offset={[-2, 4]}>
                      {item.icon}
                    </Badge>
                  </button>
                </Tooltip>
              ))}
            </div>
          </nav>

          <aside className="qq-sidebar">{renderSidebar()}</aside>
          <main className="qq-main">
            {mainView === 'contacts'
              ? renderContactMain()
              : mainView === 'favorites'
                ? renderFavoriteMain()
                : renderChatMain()}
          </main>
        </div>
        {privacyMaskVisible && (
          <button type="button" className="privacy-mask" onClick={() => setPrivacyMaskVisible(false)}>
            <strong>当前窗口已隐藏</strong>
            <span>点击恢复聊天内容</span>
          </button>
        )}
      </div>

      <Modal
        title={null}
        footer={null}
        width={960}
        centered
        open={contactManagerVisible}
        closable={false}
        className="contact-manager-modal"
        onCancel={() => setContactManagerVisible(false)}
      >
        <div className="contact-manager-window">
          <aside className="contact-manager-side">
            <div className="contact-manager-lights">
              <button
                type="button"
                className="mac-dot red"
                aria-label="关闭好友管理器"
                onClick={() => setContactManagerVisible(false)}
              />
              <span className="mac-dot yellow" />
              <span className="mac-dot green" />
            </div>
            <button
              type="button"
              className={`contact-manager-all ${contactManagerGroup === CONTACT_MANAGER_ALL_GROUP ? 'active' : ''}`}
              onClick={() => setContactManagerGroup(CONTACT_MANAGER_ALL_GROUP)}
            >
              <strong>全部好友</strong>
              <span>{chatStore.contacts.length}</span>
            </button>
            <div className="contact-manager-side-label">分组</div>
            <div className="contact-manager-group-list">
              {contactManagerGroups.map((group) => (
                <div
                  key={group.name}
                  className={`contact-manager-group-item ${contactManagerGroup === group.name ? 'active' : ''}`}
                >
                  <button type="button" onClick={() => setContactManagerGroup(group.name)}>
                    <span>{group.name}</span>
                    <em>{group.count}</em>
                  </button>
                  {group.name !== DEFAULT_CONTACT_GROUP_NAME && (
                    <Tooltip title="删除分组">
                      <Button
                        type="text"
                        icon={<DeleteOutlined />}
                        onClick={() => handleDeleteContactGroup(group.name)}
                      />
                    </Tooltip>
                  )}
                </div>
              ))}
            </div>
            <button
              type="button"
              className="contact-manager-add-group"
              onClick={() => {
                setContactGroupDraft('');
                setContactGroupCreateVisible(true);
              }}
            >
              <PlusOutlined /> 添加分组
            </button>
          </aside>
          <section className="contact-manager-main">
            <div className="contact-manager-header">
              <h2>好友管理器</h2>
              <Input
                prefix={<SearchOutlined />}
                value={contactManagerSearchText}
                onChange={(event) => setContactManagerSearchText(event.target.value)}
                placeholder="搜索"
                allowClear
              />
            </div>
            <div className="contact-manager-table">
              <div className="contact-manager-table-head">
                <span />
                <span>昵称</span>
                <span>备注</span>
                <span>分组</span>
                <span>好友权限</span>
              </div>
              <div className="contact-manager-rows">
                {contactManagerContacts.length === 0 ? (
                  <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="当前分组暂无好友" />
                ) : (
                  contactManagerContacts.map((contact) => {
                    const groupName = getContactGroupName(contact);
                    return (
                      <div key={contact.id} className="contact-manager-row">
                        <span className="manager-select-dot" />
                        <span className="manager-name-cell">
                          <Avatar size={28} src={getAvatarUrl(contact.contact_user?.avatar_path)}>
                            {getInitial(getContactName(contact))}
                          </Avatar>
                          <strong>{getContactName(contact)}</strong>
                        </span>
                        <span className="manager-note-cell">{contact.display_name || contact.contact_user?.username || '-'}</span>
                        <select value={groupName} onChange={(event) => updateContactGroup(contact, event.target.value)}>
                          {contactGroupNames.map((name) => (
                            <option value={name} key={name}>
                              {name}
                            </option>
                          ))}
                        </select>
                        <span className="manager-permission-cell">聊天、资料</span>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          </section>
        </div>
      </Modal>

      <Modal
        title="添加分组"
        open={contactGroupCreateVisible}
        onCancel={() => setContactGroupCreateVisible(false)}
        onOk={handleCreateContactGroup}
        okText="确定"
        cancelText="取消"
        className="contact-group-create-modal"
      >
        <Input
          size="large"
          value={contactGroupDraft}
          onChange={(event) => setContactGroupDraft(event.target.value)}
          onPressEnter={handleCreateContactGroup}
          placeholder="填写分组"
          maxLength={24}
          autoFocus
        />
      </Modal>

      <Modal
        title="屏幕翻译"
        open={translationVisible}
        onCancel={() => setTranslationVisible(false)}
        footer={null}
        width={760}
        className="screen-translation-modal"
      >
        <div className="screen-translation-shell">
          <section>
            <div className="translation-panel-head">
              <strong>原文</strong>
              <Button
                size="small"
                onClick={() => {
                  if (translationResult?.source) {
                    void copyTextToClipboard(translationResult.source).then(() => message.success('原文已复制'));
                  }
                }}
              >
                复制原文
              </Button>
            </div>
            <pre>{translationResult?.source || '暂无内容'}</pre>
          </section>
          <section>
            <div className="translation-panel-head">
              <span>
                <strong>译文</strong>
                <em>{translationResult?.provider === 'browser' ? '浏览器翻译' : '本地词典'}</em>
              </span>
              <Button
                size="small"
                type="primary"
                disabled={translationLoading || !translationResult?.translated}
                onClick={() => {
                  if (translationResult?.translated) {
                    void copyTextToClipboard(translationResult.translated).then(() => message.success('译文已复制'));
                  }
                }}
              >
                复制译文
              </Button>
            </div>
            {translationLoading ? (
              <div className="translation-loading">翻译中...</div>
            ) : (
              <pre>{translationResult?.translated || '暂无译文'}</pre>
            )}
          </section>
        </div>
      </Modal>

      <Modal
        title={null}
        footer={null}
        width={820}
        centered
        open={addContactVisible}
        className="qq-search-modal"
        onCancel={() => {
          setAddContactVisible(false);
          setAddContactRequestVisible(false);
          setAddContactTarget(null);
          setContactNote('');
        }}
      >
        <div className="qq-search-window">
          <div className="qq-search-titlebar">
            <span className="mac-dot red" />
            <span className="mac-dot yellow" />
            <span className="mac-dot green" />
            <strong>综合搜索</strong>
          </div>
          <div className="qq-search-topline">
            <Input
              size="large"
              prefix={<SearchOutlined />}
              value={contactUsername}
              onChange={(event) => setContactUsername(event.target.value)}
              onPressEnter={() => void handleSearchUsers()}
              placeholder="输入搜索关键词"
              allowClear
            />
            <Button type="primary" size="large" loading={searchUsersLoading} onClick={() => void handleSearchUsers()}>
              搜索
            </Button>
          </div>
          <div className="qq-search-tabs" role="tablist" aria-label="添加好友搜索分类">
            {addContactTabs.map((tab) => (
              <button
                type="button"
                role="tab"
                aria-selected={addContactTab === tab.key}
                key={tab.key}
                className={addContactTab === tab.key ? 'active' : ''}
                onClick={() => setAddContactTab(tab.key)}
              >
                {tab.label}
              </button>
            ))}
          </div>
          <div className="qq-search-body">
            {addContactTab === 'all' || addContactTab === 'user' ? (
              <>
                <div className="qq-search-note-row">
                  <span>搜索后选择用户，或直接向输入的账号发送申请</span>
                  <Button icon={<UserAddOutlined />} onClick={() => openAddContactRequest(contactUsername, '账号搜索')}>
                    直接申请
                  </Button>
                </div>
                <div className="qq-recommend-tabs">
                  {addContactRecommendTags.map((tag, index) => (
                    <button type="button" className={index === 0 ? 'active' : ''} key={tag}>
                      {tag}
                    </button>
                  ))}
                </div>

                {lastUserSearchQuery ? (
                  <section className="add-contact-section">
                    <div className="add-contact-section-head">
                      <strong>用户搜索结果</strong>
                      <span>{visibleUserResults.length} 个匹配</span>
                    </div>
                    <div className="add-contact-user-list">
                      {searchUsersLoading ? (
                        <div className="request-empty">搜索中...</div>
                      ) : visibleUserResults.length === 0 ? (
                        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="没有找到可添加的用户" />
                      ) : (
                        visibleUserResults.map((user) => renderAddContactUser(user, '账号搜索'))
                      )}
                    </div>
                  </section>
                ) : (
                  <section className="add-contact-section">
                    <div className="add-contact-section-head">
                      <strong>推荐好友</strong>
                      <span>根据当前可添加账号推荐</span>
                    </div>
                    <div className="add-contact-user-list">
                      {recommendationLoading ? (
                        <div className="request-empty">推荐加载中...</div>
                      ) : visibleRecommendedUsers.length === 0 ? (
                        <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="暂无可推荐用户" />
                      ) : (
                        visibleRecommendedUsers.map((user) => renderAddContactUser(user, '好友推荐'))
                      )}
                    </div>
                  </section>
                )}
              </>
            ) : (
              <div className="qq-search-placeholder">
                <SearchOutlined />
                <strong>{addContactTabs.find((tab) => tab.key === addContactTab)?.label}</strong>
                <span>当前版本先支持用户搜索和好友推荐。</span>
              </div>
            )}
          </div>
        </div>
      </Modal>

      <Modal
        title={null}
        width={460}
        centered
        open={addContactRequestVisible}
        className="friend-request-modal"
        onCancel={() => {
          if (addContactSubmitting) return;
          setAddContactRequestVisible(false);
          setAddContactTarget(null);
          setContactNote('');
        }}
        footer={[
          <Button
            key="cancel"
            onClick={() => {
              setAddContactRequestVisible(false);
              setAddContactTarget(null);
              setContactNote('');
            }}
            disabled={addContactSubmitting}
          >
            取消
          </Button>,
          <Button
            key="submit"
            type="primary"
            icon={<UserAddOutlined />}
            loading={addContactSubmitting}
            onClick={() => void handleAddContact()}
          >
            发送申请
          </Button>,
        ]}
      >
        <div className="friend-request-panel">
          <div className="friend-request-target">
            {addContactTarget?.user ? (
              renderUserAvatar(addContactTarget.user, 48)
            ) : (
              <Avatar size={48} icon={<UserOutlined />}>
                {getInitial(addContactTarget?.username || '')}
              </Avatar>
            )}
            <div>
              <strong>
                {addContactTarget?.user ? getUserName(addContactTarget.user) : addContactTarget?.username || '添加好友'}
              </strong>
              <span>@{addContactTarget?.username || contactUsername || 'unknown'}</span>
            </div>
          </div>
          <label className="friend-request-note-label" htmlFor="friend-request-note">
            验证消息 / 备注
          </label>
          <TextArea
            id="friend-request-note"
            value={contactNote}
            onChange={(event) => setContactNote(event.target.value)}
            maxLength={100}
            showCount
            autoSize={{ minRows: 3, maxRows: 5 }}
            placeholder={getDefaultFriendRequestNote()}
          />
          <p className="friend-request-note-hint">对方会在好友通知里看到这条消息，用来确认是谁发起的申请。</p>
        </div>
      </Modal>

      <Modal
        title="修改备注"
        open={editDisplayNameVisible}
        onCancel={() => {
          setEditDisplayNameVisible(false);
          displayNameForm.resetFields();
        }}
        onOk={() => displayNameForm.submit()}
        okText="保存"
        cancelText="取消"
      >
        <Form form={displayNameForm} onFinish={handleUpdateDisplayName} layout="vertical">
          <Form.Item name="display_name" label="备注" rules={[{ max: 50, message: '备注不能超过 50 个字符' }]}>
            <Input placeholder="输入备注" />
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        open={profileVisible}
        footer={null}
        closable={false}
        centered
        width={544}
        className="profile-edit-modal"
        wrapClassName="profile-edit-modal-wrap"
        onCancel={() => setProfileVisible(false)}
      >
        <div className="profile-pop-window">
          <div className="profile-pop-titlebar">
            <button
              type="button"
              className="profile-pop-close"
              onClick={() => setProfileVisible(false)}
              aria-label="关闭资料编辑"
            />
            <strong>编辑资料</strong>
          </div>

          <div className="profile-pop-body">
            <button
              type="button"
              className="profile-avatar-edit"
              onClick={() => profileAvatarInputRef.current?.click()}
              disabled={profileAvatarUploading}
              title="更换头像"
            >
              <Avatar size={94} src={getAvatarUrl(authStore.user?.avatar_path)}>
                {getInitial(currentUserName)}
              </Avatar>
              <span className="profile-avatar-hint">{profileAvatarUploading ? '上传中' : '更换头像'}</span>
            </button>
            <input
              ref={profileAvatarInputRef}
              className="profile-avatar-input"
              type="file"
              accept="image/*"
              onChange={(event) => void handleProfileAvatarChange(event)}
            />

            <div className="profile-edit-fields">
              <label className="profile-edit-row">
                <span>昵称</span>
                <input
                  value={profileDraft.display_name}
                  onChange={(event) => updateProfileDraft('display_name', event.target.value)}
                  maxLength={PROFILE_NAME_MAX_LENGTH}
                />
                <em>{profileDraft.display_name.length}/{PROFILE_NAME_MAX_LENGTH}</em>
              </label>

              <label className="profile-edit-row">
                <span>个签</span>
                <input
                  value={profileDraft.signature}
                  onChange={(event) => updateProfileDraft('signature', event.target.value)}
                  maxLength={PROFILE_SIGNATURE_MAX_LENGTH}
                />
                <em>{profileDraft.signature.length}/{PROFILE_SIGNATURE_MAX_LENGTH}</em>
              </label>

              <label className="profile-edit-row">
                <span>性别</span>
                <select
                  value={profileDraft.gender}
                  onChange={(event) => updateProfileDraft('gender', event.target.value)}
                >
                  {getProfileOptions(genderOptions, profileDraft.gender).map((item) => (
                    <option value={item} key={item}>{item}</option>
                  ))}
                </select>
              </label>

              <label className="profile-edit-row">
                <span>生日</span>
                <input
                  type="date"
                  value={profileDraft.birthday}
                  onChange={(event) => updateProfileDraft('birthday', event.target.value)}
                />
              </label>

              <label className="profile-edit-row">
                <span>国家</span>
                <select
                  value={profileDraft.country}
                  onChange={(event) => updateProfileDraft('country', event.target.value)}
                >
                  {getProfileOptions(countryOptions, profileDraft.country).map((item) => (
                    <option value={item} key={item}>{item}</option>
                  ))}
                </select>
              </label>

              <div className="profile-edit-location">
                <label className="profile-edit-row">
                  <span>省份</span>
                  <select
                    value={profileDraft.province}
                    onChange={(event) => updateProfileDraft('province', event.target.value)}
                  >
                    <option value="">请选择</option>
                    {getProfileOptions(provinceOptions, profileDraft.province).map((item) => (
                      <option value={item} key={item}>{item}</option>
                    ))}
                  </select>
                </label>
                <label className="profile-edit-row">
                  <span>地区</span>
                  <select
                    value={profileDraft.region}
                    onChange={(event) => updateProfileDraft('region', event.target.value)}
                  >
                    <option value="">请选择</option>
                    {getProfileOptions(regionOptions, profileDraft.region).map((item) => (
                      <option value={item} key={item}>{item}</option>
                    ))}
                  </select>
                </label>
              </div>
            </div>

            <div className="profile-edit-actions">
              <Button onClick={() => setProfileVisible(false)}>
                取消
              </Button>
              <Button type="primary" loading={profileSaving} onClick={() => void handleSaveProfile()}>
                保存
              </Button>
            </div>
          </div>
        </div>
      </Modal>

      <Modal
        title="编辑个性签名"
        open={signatureVisible}
        className="limited-text-modal"
        onCancel={() => setSignatureVisible(false)}
        onOk={() => void handleSaveSignature()}
        okText="保存"
        cancelText="取消"
        confirmLoading={signatureSaving}
      >
        <TextArea
          className="limited-textarea"
          value={signatureDraft}
          onChange={(event) => setSignatureDraft(event.target.value.slice(0, 100))}
          maxLength={100}
          showCount={{ formatter: formatTextAreaCount }}
          autoSize={{ minRows: 3, maxRows: 5 }}
          placeholder="写一句个性签名，别人可以在你的资料卡看到"
        />
      </Modal>

      <Modal
        title={historyTitle || (historyMode === 'group' ? '群聊记录' : '聊天记录')}
        open={historyVisible}
        footer={null}
        width={860}
        className="history-modal"
        onCancel={() => setHistoryVisible(false)}
      >
        <div className="history-shell">
          <Input
            size="large"
            prefix={<SearchOutlined />}
            value={historyQuery}
            onChange={(event) => setHistoryQuery(event.target.value)}
            placeholder="搜索"
            suffix={<AudioOutlined />}
          />
          <div className="history-tabs">
            {[
              ['all', '全部'],
              ['image', '图片/视频'],
              ['emoji', '表情'],
              ['file', '文件'],
              ['link', '链接'],
            ].map(([key, label]) => (
              <button
                type="button"
                key={key}
                className={historyFilter === key ? 'active' : ''}
                onClick={() => setHistoryFilter(key as HistoryFilter)}
              >
                {label}
              </button>
            ))}
            <Button type="text" icon={<FilterOutlined />}>
              筛选
            </Button>
          </div>
          <div className="history-list">
            {historyLoading ? (
              <div className="history-empty">加载中...</div>
            ) : filteredHistoryMessages.length === 0 ? (
              <div className="history-empty">暂无记录</div>
            ) : (
              filteredHistoryMessages.map((msg, index) => {
                const previous = filteredHistoryMessages[index - 1];
                const messageType = normalizeMessageType(msg.type);
                const showDate = index === 0 || formatHistoryDate(previous?.createdAt) !== formatHistoryDate(msg.createdAt);
                return (
                  <div key={`history-${msg.id}-${index}`}>
                    {showDate && <h3>{formatHistoryDate(msg.createdAt)}</h3>}
                    <div className="history-row">
                      <Avatar size={38} src={getAvatarUrl(msg.senderAvatarPath)}>
                        {getInitial(msg.senderName)}
                      </Avatar>
                      <div>
                        <p>
                          {msg.senderName} <span>{formatClock(msg.createdAt)}</span>
                        </p>
                        <strong>
                          {messageType === 'image' && '图片：'}
                          {messageType === 'video' && '视频：'}
                          {messageType === 'audio' && '语音：'}
                          {messageType === 'file' && '文件：'}
                          {msg.content || (messageType === 'image' ? '图片' : '消息')}
                          {messageType === 'file' && msg.fileSize ? ` · ${formatFileSize(msg.fileSize)}` : ''}
                          {messageType === 'audio' && msg.duration ? ` · ${msg.duration}"` : ''}
                        </strong>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </Modal>

      <Modal
        title="创建群聊"
        open={createGroupVisible}
        onCancel={() => setCreateGroupVisible(false)}
        onOk={() => void createLocalGroup()}
        okText="创建"
        cancelText="取消"
        width={560}
        className="create-group-modal"
      >
        <div className="create-group-shell">
          <Input
            value={groupNameDraft}
            onChange={(event) => setGroupNameDraft(event.target.value)}
            placeholder="群聊名称"
            maxLength={40}
          />
          <label className="create-group-select">
            <span>群分类</span>
            <select value={groupCategoryDraft} onChange={(event) => setGroupCategoryDraft(event.target.value)}>
              {['我创建的群聊', '我加入的群聊', '置顶群聊'].map((category) => (
                <option key={category} value={category}>
                  {category}
                </option>
              ))}
            </select>
          </label>
          <div className="create-group-member-title">
            <strong>选择好友</strong>
            <span>{selectedGroupMemberIds.length} 人</span>
          </div>
          <div className="create-group-members">
            {chatStore.contacts.length === 0 ? (
              <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="暂无好友" />
            ) : (
              chatStore.contacts.map((contact) => {
                const memberId = contact.contact_user?.id;
                const selected = typeof memberId === 'number' && selectedGroupMemberIds.includes(memberId);

                return (
                  <button
                    type="button"
                    key={contact.id}
                    className={selected ? 'selected' : ''}
                    onClick={() => toggleCreateGroupMember(memberId)}
                  >
                    {renderAvatar(contact, 36)}
                    <span>{getContactName(contact)}</span>
                    <CheckOutlined />
                  </button>
                );
              })
            )}
          </div>
        </div>
      </Modal>

      <Modal
        title="创建笔记"
        open={favoriteNoteVisible}
        className="limited-text-modal"
        onCancel={() => setFavoriteNoteVisible(false)}
        onOk={() => void addFavoriteNote()}
        okText="收藏"
        cancelText="取消"
        width={520}
      >
        <TextArea
          className="limited-textarea"
          value={favoriteNoteDraft}
          onChange={(event) => setFavoriteNoteDraft(event.target.value)}
          autoSize={{ minRows: 5, maxRows: 9 }}
          maxLength={1000}
          showCount={{ formatter: formatTextAreaCount }}
          placeholder="记录一条收藏笔记"
        />
      </Modal>

      <Modal
        title={shareMode === 'forward' ? '转发' : '分享'}
        open={shareVisible}
        onCancel={() => {
          setShareVisible(false);
          setForwardPayload(null);
          setShareMode('share');
        }}
        width={760}
        className="share-modal"
        footer={[
          <Button
            key="cancel"
            onClick={() => {
              setShareVisible(false);
              setForwardPayload(null);
              setShareMode('share');
            }}
          >
            取消
          </Button>,
          <Button key="submit" type="primary" onClick={() => void confirmShare()}>
            {shareMode === 'forward' ? '转发' : '分享'}
          </Button>,
        ]}
      >
        <div className="share-shell">
          <section className="share-targets">
            <Input
              prefix={<SearchOutlined />}
              value={shareSearchText}
              onChange={(event) => setShareSearchText(event.target.value)}
              placeholder="搜索好友或群聊"
              allowClear
            />
            <div className={`share-quick-actions ${shareMode === 'forward' ? 'forward-mode' : ''}`}>
              <Button icon={<TeamOutlined />} onClick={() => setCreateGroupVisible(true)}>
                创建群聊并{shareMode === 'forward' ? '转发' : '分享'}
              </Button>
              {shareMode === 'share' && (
                <Button icon={<ShareAltOutlined />} onClick={() => void handleNativeShare()}>
                  分享到微信
                </Button>
              )}
            </div>
            <div className="share-target-list">
              {recentShareTargets.length === 0 ? (
                <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="没有匹配对象" />
              ) : (
                recentShareTargets.map((target) => (
                  <button
                    type="button"
                    key={target.id}
                    className={selectedShareTargetIds.includes(target.id) ? 'selected' : ''}
                    onClick={() => toggleShareTarget(target.id)}
                  >
                    {target.type === 'group' ? (
                      <Avatar size={38} icon={<TeamOutlined />} />
                    ) : (
                      <Avatar size={38} src={getAvatarUrl(target.avatarPath)}>
                        {getInitial(target.name)}
                      </Avatar>
                    )}
                    <span>{target.name}</span>
                    <CheckOutlined />
                  </button>
                ))
              )}
            </div>
          </section>
          <section className="share-selection">
            <h3>{shareMode === 'forward' ? '转发给' : '分享到'}</h3>
            <div className="share-selected-list">
              {selectedShareTargets.length === 0 ? (
                <span className="share-selected-empty">请选择联系人或群聊</span>
              ) : (
                selectedShareTargets.map((target) => (
                  <button type="button" key={target.id} onClick={() => toggleShareTarget(target.id)}>
                    {target.type === 'group' ? <TeamOutlined /> : <UserOutlined />}
                    {target.name}
                  </button>
                ))
              )}
            </div>
            <div className="share-preview">
              <strong>{shareMode === 'forward' ? '转发内容' : '分享内容'}</strong>
              <p>{sharePayload}</p>
            </div>
            <TextArea
              value={shareNote}
              onChange={(event) => setShareNote(event.target.value)}
              autoSize={{ minRows: 3, maxRows: 5 }}
              maxLength={300}
              placeholder="给好友留言"
            />
          </section>
        </div>
      </Modal>

      <CallModal />
      <CallPage />
    </div>
  );
});

export default ChatPage;
