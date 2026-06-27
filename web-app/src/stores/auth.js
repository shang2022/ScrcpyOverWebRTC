import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('auth_token') || '')
  const username = ref(localStorage.getItem('auth_user') || '')
  const role = ref(localStorage.getItem('auth_role') || '')
  const assignedDevices = ref(JSON.parse(localStorage.getItem('auth_devices') || '[]'))
  const noAuthMode = ref(false)

  const isLoggedIn = computed(() => noAuthMode.value || !!token.value)
  const isAdmin = computed(() => noAuthMode.value || role.value === 'admin')

  async function login(user, pass) {
    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username: user, password: pass })
      })

      if (!response.ok) {
        const errText = await response.text()
        throw new Error(errText || '登录失败')
      }

      const data = await response.json()
      token.value = data.token
      username.value = data.username
      role.value = data.role || 'user'
      assignedDevices.value = data.assigned_devices || []

      localStorage.setItem('auth_token', data.token)
      localStorage.setItem('auth_user', data.username)
      localStorage.setItem('auth_role', data.role || 'user')
      localStorage.setItem('auth_devices', JSON.stringify(data.assigned_devices || []))
      return true
    } catch (error) {
      console.error('Login error:', error)
      throw error
    }
  }

  async function register(user, pass) {
    try {
      const response = await fetch('/api/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username: user, password: pass })
      })

      if (!response.ok) {
        const errText = await response.text()
        throw new Error(errText || '注册失败')
      }
      return true
    } catch (error) {
      console.error('Register error:', error)
      throw error
    }
  }

  async function logout() {
    try {
      if (token.value) {
        await fetch('/api/logout', {
          method: 'POST'
        })
      }
    } catch (error) {
      console.error('Logout error:', error)
    } finally {
      token.value = ''
      username.value = ''
      role.value = ''
      assignedDevices.value = []
      noAuthMode.value = false
      localStorage.removeItem('auth_token')
      localStorage.removeItem('auth_user')
      localStorage.removeItem('auth_role')
      localStorage.removeItem('auth_devices')
      window.location.href = '/login'
    }
  }

  async function checkNoAuthStatus() {
    try {
      const res = await fetch('/api/auth-status')
      if (res.ok) {
        const data = await res.json()
        if (data.noAuth) {
          noAuthMode.value = true
          username.value = 'admin'
          role.value = 'admin'
          assignedDevices.value = ['*']
        }
      }
    } catch (e) {
      // 请求失败说明需要正常认证，忽略
    }
  }

  return {
    token,
    username,
    role,
    assignedDevices,
    noAuthMode,
    isLoggedIn,
    isAdmin,
    login,
    register,
    logout,
    checkNoAuthStatus
  }
})
