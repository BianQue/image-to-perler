import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import type { Project } from './core';

export class BeadView {
  private renderer: THREE.WebGLRenderer;
  private scene = new THREE.Scene();
  private camera = new THREE.PerspectiveCamera(40, 1, .1, 2000);
  private controls: OrbitControls;
  private observer: ResizeObserver;
  private beads: THREE.InstancedMesh | null = null;
  private geometry: THREE.ExtrudeGeometry;
  private material = new THREE.MeshStandardMaterial({ roughness: .48, metalness: 0 });
  private frame = 0;
  private dimensions = '';
  private project: Project | null = null;
  private editing = false;
  private melt = 0;
  private grid: THREE.LineSegments | null = null;
  private cursor = 0;
  private marker = new THREE.Mesh(new THREE.PlaneGeometry(.96, .96), new THREE.MeshBasicMaterial({ color: 0x2459ce, transparent: true, opacity: .35, side: THREE.DoubleSide, depthTest: false }));
  private showCursor() {
    this.marker.visible = this.editing && !!this.project;
    if (this.project) this.marker.position.set(this.cursor % this.project.width - (this.project.width - 1) / 2, .82, Math.floor(this.cursor / this.project.width) - (this.project.height - 1) / 2);
    this.requestRender();
  }
  private dragging = false;
  private lastIndex = -1;
  private ray = new THREE.Raycaster();
  private plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  setEditing(value: boolean) { this.editing = value; this.showCursor(); this.renderer.domElement.style.cursor = value ? 'crosshair' : 'grab'; }
  setMelt(value: number) {
    this.melt = value; const old = this.geometry; this.geometry = this.makeGeometry();
    if (this.project) this.update(this.project); old.dispose();
  }
  private makeGeometry() {
    const shape = new THREE.Shape(); shape.absarc(0, 0, .45 + this.melt * .05, 0, Math.PI * 2, false);
    const hole = new THREE.Path(); hole.absarc(0, 0, .18 * (1 - this.melt) + .015 * this.melt, 0, Math.PI * 2, true); shape.holes.push(hole);
    const geometry = new THREE.ExtrudeGeometry(shape, { depth: .75 - this.melt * .5, bevelEnabled: true, bevelSegments: 1, steps: 1, bevelSize: .025, bevelThickness: .025, curveSegments: 10 });
    geometry.rotateX(-Math.PI / 2); return geometry;
  }
  private point(event: PointerEvent) {
    if (!this.project) return -1;
    const box = this.renderer.domElement.getBoundingClientRect();
    this.ray.setFromCamera(new THREE.Vector2((event.clientX - box.left) / box.width * 2 - 1, 1 - (event.clientY - box.top) / box.height * 2), this.camera);
    const hit = this.ray.ray.intersectPlane(this.plane, new THREE.Vector3()); if (!hit) return -1;
    const x = Math.floor(hit.x + this.project.width / 2), y = Math.floor(hit.z + this.project.height / 2);
    return x >= 0 && y >= 0 && x < this.project.width && y < this.project.height ? y * this.project.width + x : -1;
  }

  constructor(private container: HTMLElement, onEdit: (index: number, phase: 'start' | 'move' | 'end') => void) {
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.setClearColor(0xf1f2f3);
    this.renderer.domElement.setAttribute('aria-label', '拼豆三维预览，可拖动旋转和滚轮缩放');
    this.container.replaceChildren(this.renderer.domElement);
    const surface = this.renderer.domElement; surface.tabIndex = 0;
    surface.addEventListener('pointerdown', event => {
      if (!this.editing || event.button !== 0 || event.altKey) return;
      event.stopImmediatePropagation(); event.preventDefault(); surface.focus();
      const index = this.point(event); if (index < 0) return;
      this.dragging = true; this.cursor = index; this.lastIndex = index; surface.setPointerCapture(event.pointerId); onEdit(index, 'start');
    }, true);
    surface.addEventListener('pointermove', event => {
      const index = this.point(event); if (index >= 0) { this.cursor = index; this.showCursor(); }
      if (!this.dragging) return;
      event.stopImmediatePropagation();
      if (index >= 0 && index !== this.lastIndex) { this.lastIndex = index; onEdit(index, 'move'); }
    }, true);
    const finish = () => { if (this.dragging) { this.dragging = false; onEdit(this.cursor, 'end'); } };
    surface.addEventListener('pointerup', event => { if (this.dragging) { event.stopImmediatePropagation(); finish(); } }, true);
    surface.addEventListener('pointercancel', finish); surface.addEventListener('lostpointercapture', finish);
    surface.addEventListener('keydown', event => {
      if (!this.editing || !this.project) return;
      const delta: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -this.project.width, ArrowDown: this.project.width };
      if (event.key in delta) { event.preventDefault(); this.cursor = Math.max(0, Math.min(this.project.cells.length - 1, this.cursor + delta[event.key])); this.showCursor(); surface.title = `列 ${this.cursor % this.project.width + 1} · 行 ${Math.floor(this.cursor / this.project.width) + 1}`; }
      if (event.key === ' ') { event.preventDefault(); onEdit(this.cursor, 'start'); onEdit(this.cursor, 'end'); }
    });
    this.controls = new OrbitControls(this.camera, surface);
    this.controls.enableDamping = false;
    this.controls.addEventListener('change', this.requestRender);
    this.scene.add(new THREE.HemisphereLight(0xffffff, 0x767080, 2.5));
    const light = new THREE.DirectionalLight(0xffffff, 3); light.position.set(-30, 60, 40); this.scene.add(light);
    this.marker.rotation.x = -Math.PI / 2; this.marker.visible = false; this.marker.renderOrder = 1; this.scene.add(this.marker);
    this.geometry = this.makeGeometry();
    this.observer = new ResizeObserver(() => this.resize()); this.observer.observe(container); this.resize();
  }
  private requestRender = () => {
    if (this.frame) return;
    this.frame = requestAnimationFrame(() => { this.frame = 0; this.renderer.render(this.scene, this.camera); });
  };
  private resize() {
    const width = this.container.clientWidth, height = this.container.clientHeight;
    if (!width || !height) return;
    this.camera.aspect = width / height; this.camera.updateProjectionMatrix(); this.renderer.setSize(width, height); this.requestRender();
  }
  update(project: Project) {
    this.project = project; this.cursor = Math.min(this.cursor, project.cells.length - 1);
    if (this.beads) { this.scene.remove(this.beads); this.beads.dispose(); }
    const count = project.cells.reduce<number>((sum, id) => sum + Number(id !== null), 0);
    this.beads = new THREE.InstancedMesh(this.geometry, this.material, count);
    const matrix = new THREE.Matrix4(); const colors = new Map(project.palette.colors.map(c => [c.id, c.hex])); let instance = 0;
    project.cells.forEach((id, index) => {
      if (id === null) return;
      matrix.makeTranslation(index % project.width - (project.width - 1) / 2, 0, Math.floor(index / project.width) - (project.height - 1) / 2);
      this.beads!.setMatrixAt(instance, matrix); this.beads!.setColorAt(instance, new THREE.Color(colors.get(id)!)); instance++;
    });
    this.beads.instanceMatrix.needsUpdate = true;
    if (this.beads.instanceColor) this.beads.instanceColor.needsUpdate = true;
    this.beads.computeBoundingSphere(); this.scene.add(this.beads);
    const dimensions = `${project.width}:${project.height}`;
    if (dimensions !== this.dimensions) {
      if (this.grid) { this.scene.remove(this.grid); this.grid.geometry.dispose(); (this.grid.material as THREE.Material).dispose(); }
      const vertices: number[] = [], w = project.width, h = project.height;
      for (let x = 0; x <= w; x++) vertices.push(x - w / 2, -.04, -h / 2, x - w / 2, -.04, h / 2);
      for (let y = 0; y <= h; y++) vertices.push(-w / 2, -.04, y - h / 2, w / 2, -.04, y - h / 2);
      const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
      this.grid = new THREE.LineSegments(geometry, new THREE.LineBasicMaterial({ color: 0x9ca3af })); this.scene.add(this.grid);
      const size = Math.max(project.width, project.height); this.camera.position.set(size * .6, size * 1.7, size * 1.5);
      this.controls.target.set(0, 0, 0); this.controls.maxDistance = size * 8; this.controls.minDistance = 2; this.controls.update(); this.dimensions = dimensions;
    }
    this.requestRender();
  }
  dispose() {
    if (this.grid) { this.grid.geometry.dispose(); (this.grid.material as THREE.Material).dispose(); }
    this.marker.geometry.dispose(); this.marker.material.dispose();
    cancelAnimationFrame(this.frame); this.observer.disconnect(); this.controls.dispose(); this.beads?.dispose(); this.geometry.dispose(); this.material.dispose(); this.renderer.dispose(); this.renderer.forceContextLoss(); this.container.replaceChildren();
  }
}
